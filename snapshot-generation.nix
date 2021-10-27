{ runCommand, db-analyser, chain, cardano-node-snapshot }:

let
  chainRange = builtins.fromJSON (builtins.readFile ./chain-range.json);
  snapshotSlot = chainRange.snapshotSlot;
  finalEpoch   = chainRange.finalImmFile;
  secondLastEpoch = finalEpoch - 1; # todo, second last chunk, not epoch
  chain' = chain.override { upToChunk = finalEpoch; };
  partialChain = runCommand "partial-chain-${toString finalEpoch}" {} ''
    mkdir -p $out/immutable
    cd $out
    ln -s ${chain'}/protocolMagicId protocolMagicId
    for epoch in {00000..${toString secondLastEpoch}}; do
      ln -s ${chain'}/immutable/''${epoch}.{chunk,primary,secondary} immutable
    done
    cp ${chain'}/immutable/0${toString finalEpoch}.{chunk,primary,secondary} immutable
  '';
in runCommand "snapshot-generation" {
  buildInputs = [ db-analyser ];
  inherit finalEpoch snapshotSlot;
} ''
  cp -r ${partialChain} chain
  chmod +w -R chain

  cp ${cardano-node-snapshot}/configuration/cardano/*-genesis.json .

  { while true; do sleep 3600; echo not silent; done } &

  db-analyser --db chain/ cardano --configByron mainnet-byron-genesis.json --configShelley mainnet-shelley-genesis.json --nonce 1a3be38bcbb7911969283716ad7aa550250226b76a61fc51cc9a9a35d9276d81 --configAlonzo mainnet-alonzo-genesis.json --store-ledger ${toString snapshotSlot}

  ls -ltrh chain/ledger

  mv chain/ledger/${toString snapshotSlot}_db-analyser temp
  rm chain/ledger/*
  mv temp chain/ledger/${toString snapshotSlot}

  mkdir $out
  mv chain $out/
''
