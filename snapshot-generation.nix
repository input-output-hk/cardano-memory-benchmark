{ runCommand, db-analyser, mainnet-chain, cardano-node-snapshot }:

let
  chainRange = builtins.fromJSON (builtins.readFile ./chain-range.json);
  snapshotSlot = chainRange.snapshotSlot;
  finalEpoch   = chainRange.finalImmFile;
  secondLastEpoch = finalEpoch - 1;
in runCommand "snapshot-generation" {
  buildInputs = [ db-analyser ];
  inherit finalEpoch snapshotSlot;
} ''
  mkdir -pv chain/immutable
  ln -s ${mainnet-chain}/protocolMagicId chain/protocolMagicId

  for epoch in {00000..${toString secondLastEpoch}}; do
    ln -s ${mainnet-chain}/immutable/''${epoch}.{chunk,primary,secondary} chain/immutable
  done
  cp -v ${mainnet-chain}/immutable/0${toString finalEpoch}.{chunk,primary,secondary} chain/immutable
  chmod +w -R chain

  cp ${cardano-node-snapshot}/configuration/cardano/*-genesis.json .

  db-analyser --db chain/ cardano --configByron mainnet-byron-genesis.json --configShelley mainnet-shelley-genesis.json --nonce 1a3be38bcbb7911969283716ad7aa550250226b76a61fc51cc9a9a35d9276d81 --configAlonzo mainnet-alonzo-genesis.json --store-ledger ${toString snapshotSlot}

  ls -ltrh chain/ledger

  mv -v chain/ledger/${toString snapshotSlot}_db-analyser temp
  rm -v chain/ledger/*
  mv -vi temp chain/ledger/${toString snapshotSlot}

  pwd
  ls -ltrh chain/
  mkdir $out
  mv chain $out/
''
