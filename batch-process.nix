{ lib, bash, runCommand, jq
, membench
, batch
, cardano-node-process
}:

runCommand "batch-${batch.name}-results.json" {
  requiredSystemFeatures = [ "benchmark" ];
  preferLocalBuild = true;
  nativeBuildInputs = [ jq ];
} ''
  ${bash}/bin/bash ${cardano-node-process}/bench/process/process.sh \
    process < ${batch}/index.json > $out
''
