{ lib, jq, runCommand, membench, variantTable, nIterations ? 1 }:

with lib;
let
  ## From the variant table (Map Name RtsFlags), derive variants of the baseline:
  allVariants =
    mapAttrs
      (name: rtsflags:
        membench.override
        { rtsflags = rtsflags;
          suffix   = "-${name}";
        })
      variantTable;

  ## For a given variant, derive its run iterations:
  variantIterationsShell =
    name: variant:
    concatMapStringsSep "\n"
      (currentIteration:
        "ln -sv ${variant.override { inherit currentIteration; }} $out/${name}-${toString currentIteration}")
      (range 1 nIterations);

  ## Derive the (variants X iterations) cross product:
  allVariantIterationsShell =
    builtins.attrValues
      (mapAttrs variantIterationsShell allVariants);

  nVariants = length (__attrNames variantTable);

in runCommand "membench-matrix-${toString nVariants}vars-${toString nIterations}runs" {
  preferLocalBuild = true;
  nativeBuildInputs = [ jq ];
} ''
  mkdir -p $out/nix-support
  ${concatStringsSep "\n" allVariantIterationsShell}

  cd $out

  cp ${./render_html.jq} render_html.jq
  cat */refined.json | jq --slurp 'include "render_html"; . | render_html' --raw-output > $out/render.html

  tar -cf alljson.tar */*.json */input/*.json */input/highwater */input/rts.dump */input/stderr
  gzip -9v alljson.tar

  cat > nix-support/hydra-build-products <<EOF
  file binary-dist $out/alljson.tar.gz
  report testlog $out render.html
  EOF
''
