#!/usr/bin/env cwl-runner
#
# Example validate submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: validate.R

hints:
  DockerRequirement:
    dockerPull: docker.synapse.org/syn20545112/scoring_harness

inputs:
  - id: inputfile
    type: File
  #- id: goldstandard
  #  type: File
  - id: entity_type
    type: string

arguments:
  - valueFrom: $(inputs.inputfile.path)
    prefix: -s
  #- valueFrom: $(inputs.goldstandard.path)
  #  prefix: -g
  - valueFrom: "/data/project/RA2_DREAM/leaderboard.csv"
    prefix: -g
  - valueFrom: results.json
    prefix: -r
  - valueFrom: $(inputs.entity_type)
    prefix: -e

requirements:
  - class: InlineJavascriptRequirement
     
outputs:

  - id: results
    type: File
    outputBinding:
      glob: results.json   

  - id: status
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['prediction_file_status'])

  - id: invalid_reasons
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['prediction_file_errors'])
