#!/usr/bin/env cwl-runner
#
# Run Docker Submission
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python

inputs:
  - id: submissionid
    type: int
  - id: docker_repository
    type: string
  - id: docker_digest
    type: string
  - id: parentid
    type: string
  - id: status
    type: string
  - id: synapse_config
    type: File
  - id: train_dir
    type: string
  - id: test_dir
    type: string

arguments: 
  - valueFrom: rundocker.py
  - valueFrom: $(inputs.submissionid)
    prefix: -s
  - valueFrom: $(inputs.docker_repository)
    prefix: -p
  - valueFrom: $(inputs.docker_digest)
    prefix: -d
  - valueFrom: $(inputs.status)
    prefix: --status
  - valueFrom: $(inputs.parentid)
    prefix: --parentid
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.train_dir)
    prefix: --train_dir
  - valueFrom: $(inputs.test_dir)
    prefix: --test_dir

requirements:
  - class: InitialWorkDirRequirement
    listing:
      - entryname: rundocker.py
        entry: |
          import argparse
          import os
          import time
          import signal
          import subprocess
          # import pyslurm

          from threading import Event
          from functools import partial
          import synapseclient

          exit = Event()


          def check_existing_job(submissionid):
              """Check for existing slurm jobs"""
              # slurm = pyslurm.job()
              # jobid = slurm.find(name="name", val=submissionid)
              commands = ['squeue', '--name', str(submissionid)]
              jobid = subprocess.check_output(commands)
              jobids = jobid.decode().split("\n")
              running = jobids[1] != ''
              return running


          def check_log_and_upload(syn, log_path, parentid):
              """Check log and upload"""
              if os.path.exists(log_path):
                  log_file_info = os.stat(log_path)
                  if log_file_info.st_size > 0:
                      ent = synapseclient.File(log_path, parent=parentid)
                      try:
                          logs = syn.store(ent)
                      except synapseclient.exceptions.SynapseHTTPError:
                          pass


          def main(args):
              # Exit out of workflow if Docker image is invalid
              if args.status == "INVALID":
                  raise Exception("Docker image is invalid")

              syn = synapseclient.Synapse(configPath=args.synapse_config)
              syn.login()

              docker_image = "docker://" + args.docker_repository + "@" + args.docker_digest
              #These are the volumes that you want to mount onto your docker container
              output_dir = os.getcwd()
              train_dir = args.train_dir
              test_dir = args.test_dir
              # Format singularity command
              singularity_command = ['singularity exec',
                                    '--net',
                                    '--no-home',
                                    '--bind', '/cm/local/apps/cuda/libs',
                                    '--nv',
                                    '-B',
                                    '/data/scratch/thomas.yu@sagebionetworks.org/:/tmp:rw',
                                    '-B',
                                    '{}:/train:ro'.format(train_dir),
                                    '-B',
                                    '{}:/test:ro'.format(test_dir),
                                    '-B',
                                    '{}:/output:rw'.format(output_dir),
                                    docker_image,
                                    '/run.sh']
              submissionid = str(args.submissionid)
              # Format shell script
              shell_file = ['#!/bin/bash',
                            '#SBATCH --partition=pascalnodes',
                            '#SBATCH --job-name={submissionid}',
                            '#SBATCH --time=16:00:00',
                            '#SBATCH --mail-type=FAIL',
                            '#SBATCH --mail-user=thomas.yu@sagebionetworks.org',
                            '#SBATCH --output={submissionid}.txt',
                            '#SBATCH --error={submissionid}_errors.txt',
                            '#SBATCH --cpus-per-task=8',
                            '#SBATCH --mem=32G',
                            '#SBATCH --gres=gpu:1',
                            '#SBATCH --account=ra2_dream',
                            'source /home/thomas.yu@sagebionetworks.org/.bash_profile',
                            'module load Singularity/2.6.1-GCC-5.4.0-2.26',
                            ' '.join(singularity_command)]

              shell_text = "\n".join(shell_file).format(submissionid=submissionid)
              with open(submissionid + ".sh", "w") as submission_sh:
                  submission_sh.write(shell_text)

              # Look for existing job, if job doesn't exist, start the job
              running = check_existing_job(submissionid)

              std_out_file = submissionid + '.txt'
              std_err_file = submissionid + '_errors.txt'
              # Start batch job with subprocess if log doesn't exist
              # or job isn't running
              if not running and not os.path.exists(std_out_file):
                  sbatch_command = ['sbatch', submissionid + ".sh"]
                  subprocess.check_call(sbatch_command)
                  time.sleep(5)

              # Get job info
              # jobid = slurm.find(name="name", val=submissionid)

              running = check_existing_job(submissionid)

              while running:
                  check_log_and_upload(syn, std_out_file, args.parentid)
                  check_log_and_upload(syn, std_err_file, args.parentid)
                  time.sleep(60)
                  running = check_existing_job(submissionid)

              time.sleep(60)
              #Must run again to make sure all the logs are captured
              check_log_and_upload(syn, std_out_file, args.parentid)
              check_log_and_upload(syn, std_err_file, args.parentid)

          def quit(signo, _frame, submissionid=None):
              print("Interrupted by {}, shutting down".format(signo))
              running = check_existing_job(submissionid)

              if running:
                  try:
                      scancel_command = ['scancel', '-n', submissionid, '-p', 'express']
                      subprocess.check_call(scancel_command)
                      std_out_file = submissionid + '.txt'
                      std_err_file = submissionid + '_errors.txt'
                      os.unlink(std_out_file)
                      os.unlink(std_err_file)
                  except Exception:
                      pass
              exit.set()


          if __name__ == '__main__':
              parser = argparse.ArgumentParser()
              parser.add_argument("-s", "--submissionid", required=True, help="Submission Id")
              parser.add_argument("-p", "--docker_repository", required=True, help="Docker Repository")
              parser.add_argument("-d", "--docker_digest", required=True, help="Docker Digest")
              parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
              parser.add_argument("--parentid", required=True, help="Parent Id of submitter directory")
              parser.add_argument("--status", required=True, help="Docker image status")
              parser.add_argument("--train_dir", required=True, help="Train Directory")
              parser.add_argument("--test_dir", required=True, help="Test Directory")
              args = parser.parse_args()

              quit_sub = partial(quit, submissionid=args.submissionid)
              for sig in ('TERM', 'HUP', 'INT'):
                  signal.signal(getattr(signal, 'SIG'+sig), quit_sub)

              main(args)

  - class: InlineJavascriptRequirement

outputs:
  predictions:
    type: File
    outputBinding:
      glob: predictions.csv
