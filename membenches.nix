{ membench, variantTable, lib, runCommand, rerunCount ? 5 }:

let
  variants = lib.mapAttrs (k: v: membench.override { rtsflags = v; }) variantTable;
  makeNLinks = k: v: lib.concatMapStringsSep "\n" (n: "ln -sv ${v.override { inherit n; }} $out/${k}-${toString n}") (lib.range 1 rerunCount);
  symlinks = builtins.attrValues (lib.mapAttrs makeNLinks variants);
in
  runCommand "membenches" {} ''
    mkdir $out
    ${lib.concatStringsSep "\n" symlinks}
  ''
