{ membench, variantTable, lib, runCommand, rerunCount ? 2 }:

let
  variants = lib.mapAttrs (k: v: membench.override { rtsflags = v; }) variantTable;
  makeNLinks = k: v: lib.concatMapStringsSep "\n" (n: "ln -sv ${v.override { inherit n; }} $out/${k}-${toString n}") (lib.range 1 rerunCount);
  symlinks = builtins.attrValues (lib.mapAttrs makeNLinks variants);
in
runCommand "membenches" {
  preferLocalBuild = true;
} ''
  mkdir -p $out/nix-support
  ${lib.concatStringsSep "\n" symlinks}

  cd $out
  tar -cf alljson.tar */*.json */input/*.json */input/highwater */input/rts.dump */input/stderr
  gzip -9v alljson.tar
  echo "file binary-dist $out/alljson.tar.gz" >> nix-support/hydra-build-products
''
