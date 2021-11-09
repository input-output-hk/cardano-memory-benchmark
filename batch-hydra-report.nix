{ lib, jq, runCommand
, membench
, cardano-node-process
, batch
}:

runCommand "batch-report-${batch.batch-id}" {
  preferLocalBuild = true;
} ''
  mkdir -p $out/nix-support

  cd $out

  cp ${./render_html.jq} render_html.jq
  cat */refined.json | jq --slurp 'include "render_html"; . | render_html' --raw-output > $out/render.html

  cat > nix-support/hydra-build-products <<EOF
  report testlog $out render.html
  EOF
''
