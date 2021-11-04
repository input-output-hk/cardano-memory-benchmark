{ membenches, runCommand }:

runCommand "post-process" {
  preferLocalBuild = true;
} ''
  mkdir -p $out/nix-support

  cp -vr ${./bench} bench
  chmod -R +w bench
  patchShebangs bench

  ls -lh ${membenches}

  #bench/process.sh
''
