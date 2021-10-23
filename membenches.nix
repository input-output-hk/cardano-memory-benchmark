{ membench, variantTable, lib, runCommand, rerunCount ? 1, jq }:

let
  variants = lib.mapAttrs (k: v: membench.override { rtsflags = v; }) variantTable;
  makeNLinks = k: v: lib.concatMapStringsSep "\n" (n: "ln -sv ${v.override { inherit n; }} $out/${k}-${toString n}") (lib.range 1 rerunCount);
  symlinks = builtins.attrValues (lib.mapAttrs makeNLinks variants);
in
runCommand "membenches" {
  preferLocalBuild = true;
  nativeBuildInputs = [ jq ];
} ''
  mkdir -p $out/nix-support
  ${lib.concatStringsSep "\n" symlinks}

  cd $out

  cp -vr ${./bench} bench
  chmod -R +w bench
  patchShebangs bench

  #bench/process.sh

  cp ${./render_html.jq} render_html.jq
  cat */refined.json | jq --slurp 'include "render_html"; . | render_html' --raw-output > $out/render.html

  tar -cf alljson.tar */*.json */input/*.json */input/highwater */input/rts.dump */input/stderr
  gzip -9v alljson.tar

  cat > nix-support/hydra-build-products <<EOF
  file binary-dist $out/alljson.tar.gz
  report testlog $out render.html
  EOF
''
