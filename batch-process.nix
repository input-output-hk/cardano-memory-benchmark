{ lib, bash, runCommand, jq
, membench
, batch
, inputs
, cardano-node-process
}:

runCommand "membench-results-${batch.batch-id}-process-${inputs.cardano-node-process.shortRev}.json" {
  requiredSystemFeatures = [ "benchmark" ];
  preferLocalBuild = true;
  nativeBuildInputs = [ jq ];
} ''
  echo "membench | process:  processing batch ${batch.batch-id}"

  ${bash}/bin/bash ${cardano-node-process}/bench/process/process.sh \
    process < ${batch}/index.json > $out

  cat $out
''
