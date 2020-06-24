#!/usr/bin/env cwl-runner
#
# Sample workflow
# Inputs:
#   submissionId: ID of the Synapse submission to process
#   adminUploadSynId: ID of a folder accessible only to the submission queue administrator
#   submitterUploadSynId: ID of a folder accessible to the submitter
#   workflowSynapseId:  ID of the Synapse entity containing a reference to the workflow file(s)
#
cwlVersion: v1.0
class: Workflow

requirements:
  - class: StepInputExpressionRequirement

inputs:
  - id: submissionId
    type: int
  - id: adminUploadSynId
    type: string
  - id: submitterUploadSynId
    type: string
  - id: workflowSynapseId
    type: string
  - id: synapseConfig
    type: File

# there are no output at the workflow engine level.  Everything is uploaded to Synapse
outputs: []

steps:

  set_permissions:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/synapse-docker/set_permissions.cwl
    in:
      - id: entityid
        source: "#submitterUploadSynId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: principalid
        valueFrom: "3392644"
      - id: permissions
        valueFrom: "download"
    out: []

  set_admin_permissions:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/synapse-docker/set_permissions.cwl
    in:
      - id: entityid
        source: "#adminUploadSynId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: principalid
        valueFrom: "3392644"
      - id: permissions
        valueFrom: "download"
    out: []

  get_docker_submission:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/synapse-docker/get_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: docker_repository
      - id: docker_digest
      - id: entity_type
      - id: filepath
      - id: results
      - id: entity_id

  validate_docker:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/synapse-docker/validate_docker.cwl
    in:
      - id: docker_repository
        source: "#get_docker_submission/docker_repository"
      - id: docker_digest
        source: "#get_docker_submission/docker_digest"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: results
      - id: status
      - id: invalid_reasons

  annotate_docker_validation_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/synapse-docker/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#validate_docker/results"
      - id: to_public
        default: true
      - id: force_change_annotation_acl
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  run_docker:
    run: sbatch_singularity.cwl
    in:
      - id: docker_repository
        source: "#get_docker_submission/docker_repository"
      - id: docker_digest
        source: "#get_docker_submission/docker_digest"
      - id: submissionid
        source: "#submissionId"
      - id: status
        source: "#validate_docker/status"
      - id: parentid
        source: "#submitterUploadSynId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: train_dir
        valueFrom: "/data/project/RA2_DREAM/train"
      - id: test_dir
        valueFrom: "/data/project/RA2_DREAM/test_leaderboard"
    out:
      - id: predictions

  upload_results:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/synapse-docker/upload_to_synapse.cwl
    in:
      - id: infile
        source: "#run_docker/predictions"
      - id: parentid
        source: "#adminUploadSynId"
      - id: used_entity
        source: "#get_docker_submission/entity_id"
      - id: executed_entity
        source: "#workflowSynapseId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: uploaded_fileid
      - id: uploaded_file_version
      - id: results

  annotate_docker_upload_results:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/synapse-docker/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#upload_results/results"
      - id: to_public
        default: true
      - id: force_change_annotation_acl
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_docker_validation_with_output/finished"
    out: [finished]

  validation:
    run: validate.cwl
    in:
      - id: inputfile
        source: "#run_docker/predictions"
      # Entity type isn't passed in because docker file prediction files are passed
      # From the docker run command
      - id: entity_type
        valueFrom: "none"
      - id: goldstandard
        default:
          class: File
          location: "/data/project/RA2_DREAM/leaderboard.csv"
    out:
      - id: results
      - id: status
      - id: invalid_reasons
  
  validation_email:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/synapse-docker/validate_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: status
        source: "#validation/status"
      - id: invalid_reasons
        source: "#validation/invalid_reasons"
      - id: errors_only
        default: true
    out: [finished]

  annotate_validation_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/synapse-docker/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#validation/results"
      - id: to_public
        default: true
      - id: force_change_annotation_acl
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_docker_upload_results/finished"
    out: [finished]

  check_status:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.0/check_status.cwl
    in:
      - id: status
        source: "#validation/status"
      - id: previous_annotation_finished
        source: "#annotate_validation_with_output/finished"
      - id: previous_email_finished
        source: "#validation_email/finished"
    out: [finished]

  scoring:
    run: score.cwl
    in:
      - id: inputfile
        source: "#run_docker/predictions"
      - id: goldstandard
        default:
          class: File
          location: "/data/project/RA2_DREAM/leaderboard.csv"
      - id: check_validation_finished
        source: "#check_status/finished"
    out:
      - id: results

  switch_annotations:
    run: switch_annotation.cwl
    in:
      - id: inputjson
        source: "#scoring/results"
      - id: leaderboard
        default: true
    out:
      - id: results

  annotate_submission_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/synapse-docker/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#switch_annotations/results"
      - id: to_public
        default: true
      - id: force_change_annotation_acl
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_validation_with_output/finished"
    out: [finished]
 
  ##### FINAL ROUND
  final_run_docker:
    run: sbatch_singularity.cwl
    in:
      - id: docker_repository
        source: "#get_docker_submission/docker_repository"
      - id: docker_digest
        source: "#get_docker_submission/docker_digest"
      - id: submissionid
        source: "#submissionId"
      - id: status
        source: "#validation/status"
      - id: parentid
        source: "#adminUploadSynId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: train_dir
        valueFrom: "/data/project/RA2_DREAM/train"
      - id: test_dir
        valueFrom: "/data/project/RA2_DREAM/test_final"
      - id: previous
        source: "#annotate_submission_with_output/finished"
    out:
      - id: predictions

  final_upload_results:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/synapse-docker/upload_to_synapse.cwl
    in:
      - id: infile
        source: "#final_run_docker/predictions"
      - id: parentid
        source: "#adminUploadSynId"
      - id: used_entity
        source: "#get_docker_submission/entity_id"
      - id: executed_entity
        source: "#workflowSynapseId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: uploaded_fileid
      - id: uploaded_file_version
      - id: results

  final_annotate_docker_upload_results:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/synapse-docker/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#final_upload_results/results"
      - id: to_public
        default: true
      - id: force_change_annotation_acl
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_docker_validation_with_output/finished"
    out: [finished]

  final_validation:
    run: validate.cwl
    in:
      - id: inputfile
        source: "#final_run_docker/predictions"
      # Entity type isn't passed in because docker file prediction files are passed
      # From the docker run command
      - id: entity_type
        valueFrom: "none"
      - id: goldstandard
        default:
          class: File
          location: "/data/project/RA2_DREAM/test.csv"
    out:
      - id: results
      - id: status
      - id: invalid_reasons

  final_validation_email:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/synapse-docker/validate_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: status
        source: "#final_validation/status"
      - id: invalid_reasons
        source: "#final_validation/invalid_reasons"
      - id: errors_only
        default: true
    out: [finished]

  final_annotate_validation_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/synapse-docker/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#final_validation/results"
      - id: to_public
        default: true
      - id: force_change_annotation_acl
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#final_annotate_docker_upload_results/finished"
    out: [finished]

  final_check_status:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.0/check_status.cwl
    in:
      - id: status
        source: "#final_validation/status"
      - id: previous_annotation_finished
        source: "#final_annotate_validation_with_output/finished"
      - id: previous_email_finished
        source: "#final_validation_email/finished"
    out: [finished]

  final_scoring:
    run: score.cwl
    in:
      - id: inputfile
        source: "#final_run_docker/predictions"
      - id: goldstandard
        default:
          class: File
          location: "/data/project/RA2_DREAM/test.csv"
      - id: check_validation_finished
        source: "#final_check_status/finished"
    out:
      - id: results

  final_switch_annotations:
    run: switch_annotation.cwl
    in:
      - id: inputjson
        source: "#final_scoring/results"
    out:
      - id: results

  final_annotate_submission_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/synapse-docker/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#final_switch_annotations/results"
      - id: to_public
        default: false
      - id: force_change_annotation_acl
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#final_annotate_validation_with_output/finished"
    out: [finished]

  # Move leaderboard scoring email after running of test leaderboard so
  # scores are sent back at the very end
  score_email:
    run: score_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: results
        source: "#switch_annotations/results"
      - id: private_annotations
        default: ['leaderboard_sc2_hand_weighted_sum_rmse', 'leaderboard_sc2_foot_weighted_sum_rmse', 'leaderboard_sc3_hand_weighted_sum_rmse', 'leaderboard_sc3_foot_weighted_sum_rmse']
      - id: previous
        source: "#final_annotate_submission_with_output/finished"
    out: []
