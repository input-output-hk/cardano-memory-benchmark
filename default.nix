{ rtsMemSize ? null }@args:

let
  flake = builtins.getFlake (toString ./.);
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
in {
  membench = flake.packages.x86_64-linux.membench.override (lib.filterAttrs (k: v: v != null) args);
}
