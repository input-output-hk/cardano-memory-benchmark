{ membench, variantTable, lib, runCommand }:

let
  variants = lib.mapAttrs (k: v: membench.override { rtsflags = v; }) variantTable;
  symlinks = builtins.attrValues (lib.mapAttrs (k: v: "ln -sv ${v} $out/${k}") variants);
in
  runCommand "membenches" {} ''
    mkdir $out
    ${lib.concatStringsSep "\n" symlinks}
  ''
