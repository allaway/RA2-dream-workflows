# instructions for setting up UAB infra
module load Anaconda3
conda create --name cwl python=3
source activate cwl
pip install wes-service --user
pip install cwltool --user
pip install pyslurm --user
# pip install toil[all]

# Start server locally... 
# you need to start the server first, which will be serving on some host and port
# then use the client to actually run stuff
screen
#wes-server --port 8082 --backend=wes_service.toil_wes --opt extra=--clean=never

wes-server --backend=wes_service.cwl_runner --opt runner=cwltool --opt extra=--singularity --opt extra=--cachedir=/home/thomas.yu@sagebionetworks.org/cache_workflows/ --port 8082
#Use the key sequence Ctrl-a + Ctrl-d to detach from the screen session.
#Use the key sequence Ctrl-a + H to obtain logs

export WES_API_HOST=localhost:8082
export WES_API_AUTH='Header: value'
export WES_API_PROTO=http

git clone https://github.com/common-workflow-language/workflow-service.git
cd workflow-servce

wes-client --info

wes-client --attachments="testdata/dockstore-tool-md5sum.cwl,testdata/md5sum.input" testdata/md5sum.cwl testdata/md5sum.cwl.json --no-wait

wes-client --attachments="testtool.cwl,testtool.json" testtool.cwl testtool.json --no-wait

wes-client --list

git clone https://github.com/Sage-Bionetworks/ChallengeWorkflowTemplates.git
cd ChallengeWorkflowTemplates
wes-client scoring_harness_workflow.cwl scoring_harness_workflow.yaml  --attachments="download_submission_file.cwl,validate_email.cwl,validate.cwl,score.cwl,score_email.cwl,download_from_synapse.cwl,check_status.cwl,annotate_submission.cwl" --no-wait


# curl localhost:8082/ga4gh/wes/v1/runs/<jobid>/cancel