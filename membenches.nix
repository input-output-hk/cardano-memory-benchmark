{ lib, jq, runCommand, membench, variantTable, nIterations ? 1 }:

let
  variants = lib.mapAttrs (k: v: membench.override { rtsflags = v; suffix = "-${k}";}) variantTable;
  makeNLinks =
    k: v:
    lib.concatMapStringsSep "\n"
      (currentIteration: "ln -sv ${v.override { inherit currentIteration; }} $out/${k}-${toString currentIteration}")
      (lib.range 1 nIterations);
  symlinks = builtins.attrValues (lib.mapAttrs makeNLinks variants);
  mergedResult = runCommand "membenches" {
    preferLocalBuild = true;
    nativeBuildInputs = [ jq ];
  } ''
    mkdir -p $out/nix-support
    ${lib.concatStringsSep "\n" symlinks}

    cd $out


    cp ${./render_html.jq} render_html.jq
    cat */refined.json | jq --slurp 'include "render_html"; . | render_html' --raw-output > $out/render.html

    tar -cf alljson.tar */*.json */input/*.json */input/highwater */input/rts.dump */input/stderr
    gzip -9v alljson.tar

    cat > nix-support/hydra-build-products <<EOF
    file binary-dist $out/alljson.tar.gz
    report testlog $out render.html
    EOF
  '';
in runCommand "post-processed" {
  preferLocalBuild = true;
} ''
  mkdir -p $out/nix-support
  cp ${mergedResult}/nix-support/* $out/nix-support
  chmod -R +w $out

  cp -vr ${./bench} bench
  chmod -R +w bench
  patchShebangs bench

  #bench/process.sh
''
