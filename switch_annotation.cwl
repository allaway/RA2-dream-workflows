#!/usr/bin/env cwl-runner
#
# Switches subchallenge 2 annotations with subchallenge 3 annotations
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python3

hints:
  DockerRequirement:
    dockerPull: docker.synapse.org/syn18058986/synapsepythonclient:1.9.2

inputs:
  - id: inputjson
    type: File
  - id: leaderboard?
    type: boolean

arguments:
  - valueFrom: switch_annotation.py
  - valueFrom: $(inputs.inputjson.path)
    prefix: -j
  - valueFrom: results.json
    prefix: -r
  - valueFrom: $(inputs.leaderboard)
    prefix: -l

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: switch_annotation.py
        entry: |
          #!/usr/bin/env python3
          import argparse
          import json
          parser = argparse.ArgumentParser()
          parser.add_argument("-j", "--json", required=True, help="Json input to switch")
          parser.add_argument("-r", "--results", required=True, help="Switched json")
          parser.add_argument("-l", "--leaderboard", action="store_true")

          args = parser.parse_args()
          
          with open(args.json, "r") as input:
            result = json.load(input)

          columns = ['sc2_total_weighted_sum_error', 'sc2_joint_weighted_sum_rmse', 
                     'sc3_hand_weighted_sum_rmse', 'sc3_total_weighted_sum_error',
                     'sc2_foot_weighted_sum_rmse', 'sc2_hand_weighted_sum_rmse',
                     'sc3_joint_weighted_sum_rmse', 'sc3_foot_weighted_sum_rmse']
          for col in columns:
            if result[col] != 'NA':
              result[col] = float(result[col])

          new_score = {'sc3_total_weighted_sum_error': result['sc2_total_weighted_sum_error'],
                      'sc3_joint_weighted_sum_rmse': result['sc2_joint_weighted_sum_rmse'],
                      'sc2_hand_weighted_sum_rmse': result['sc3_hand_weighted_sum_rmse'],
                      'sc2_total_weighted_sum_error': result['sc3_total_weighted_sum_error'],
                      'sc3_foot_weighted_sum_rmse': result['sc2_foot_weighted_sum_rmse'],
                      'sc3_hand_weighted_sum_rmse': result['sc2_hand_weighted_sum_rmse'],
                      'sc2_joint_weighted_sum_rmse': result['sc3_joint_weighted_sum_rmse'],
                      'sc2_foot_weighted_sum_rmse': result['sc3_foot_weighted_sum_rmse']}
          result.update(new_score)
          if args.leaderboard:
            items = result.items()
            result = {"leaderboard_" + key: value for key, value in items}
          with open(args.results, 'w') as o:
            o.write(json.dumps(result))
     
outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json