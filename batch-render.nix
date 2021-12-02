{ lib, bash, runCommand, jq
, membench
, batch
, batch-results
, cardano-node-process
}:

runCommand "batch-${batch.name}-report" {
  requiredSystemFeatures = [ "benchmark" ];
  preferLocalBuild = true;
  nativeBuildInputs = [ jq ];
} ''
  mkdir -p $out/nix-support

  ${bash}/bin/bash ${cardano-node-process}/bench/process/process.sh \
    render < ${batch-results} > $out/FIXME.json
''
