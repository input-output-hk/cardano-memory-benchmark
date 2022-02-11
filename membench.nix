{ runCommand, lib
, jq, snapshot, strace, util-linux, e2fsprogs, gnugrep, procps, time, hexdump
, inputs, cardano-node-snapshot, cardano-node-measured
, rtsflags, rtsMemSize, currentIteration ? null
, suffix ? ""
}:

let
  flags = "${rtsflags} ${lib.optionalString (rtsMemSize != null) "-M${rtsMemSize}"}";
  topology = { Producers = []; };
  topologyPath = builtins.toFile "topology.json" (builtins.toJSON topology);
  inVM = false;
  membench = runCommand "membench-node-${inputs.cardano-node-measured.rev}${suffix}" {
    outputs = [ "out" "chain" ];
    buildInputs = [ cardano-node-measured jq strace util-linux procps time ];
    succeedOnFailure = true;
    inherit currentIteration;
    requiredSystemFeatures = [ "benchmark" ];
    failureHook = ''
      egrep 'ReplayFromSnapshot|ReplayedBlock|will terminate|Ringing the node shutdown|TookSnapshot|cardano.node.resources' log.json > $out/summary.json
      mv -vi log*json config.json $out/
      mv chain $chain/
      echo $exitCode > $out/nix-support/custom-failed
      exit 0
    '';
  } ''
    mkdir -pv $out/nix-support

    ${lib.optionalString inVM ''
    echo 0 > /tmp/xchg/in-vm-exit
    echo 42 > $out/nix-support/custom-failed

    # never overcommit
    echo 2 > /proc/sys/vm/overcommit_memory
    ''}

    pwd
    free -m
    cp -r ${snapshot}/chain chain
    chmod -R +w chain

    echo ${flags}

    ls -ltrh chain
    jq '.setupScribes = [
        .setupScribes[0] * { "scFormat":"ScJson" },
        {
          scFormat:"ScJson",
          scKind:"FileSK",
          scName:"log.json",
          scRotation:{
            rpLogLimitBytes: 300000000,
            rpMaxAgeHours:   24,
            rpKeepFilesNum:  20
          }
        }
      ]
      | .defaultScribes = .defaultScribes + [ [ "FileSK", "log.json" ] ]
      '   ${cardano-node-snapshot}/configuration/cardano/mainnet-config.json > config.json
    cp -v ${cardano-node-snapshot}/configuration/cardano/*-genesis.json .

    args=( +RTS -s$out/rts.dump
                ${flags}
           -RTS
           run
           --database-path           chain/
           --config                  config.json
           --topology                ${topologyPath}
           --shutdown-on-slot-synced 200000
         )
    command time -f %M -o $out/highwater \
      cardano-node "''${args[@]}" 2>$out/stderr
    #sleep 600
    #kill -int $!

    pwd
    df -h
    free -m

    egrep 'ReplayFromSnapshot|ReplayedBlock|will terminate|Ringing the node shutdown|TookSnapshot|cardano.node.resources' log.json > $out/summary.json

    ls -ltrh chain/ledger/
    mv -vi log*json config.json $out/
    mv chain $chain
    rm $out/nix-support/custom-failed || true

    ln -s ${snapshot} $out/chaindb
    args=( --arg             measuredNodeRev  ${inputs.cardano-node-measured.rev}
         )
    jq '{ measuredNodeRev:  $measuredNodeRev
        }
       ' "''${args[@]}" > $out/run-info.json
  '';
in
runCommand "membench-run-report${suffix}" {
  requiredSystemFeatures = [ "benchmark" ];
  preferLocalBuild = true;
  buildInputs = [ jq hexdump ];
  input = membench.out;
} ''
  ls -lh $input
  mkdir $out
  cd $out
  ln -sv $input input

  # so the node wont get GC'd, and you could confirm the source it came from
  ln -s ${cardano-node-measured}/bin/cardano-node .
  totaltime=$({ head -n1 input/log.json ; tail -n1 input/log.json;} | jq --slurp 'def katip_timestamp_to_iso8601: .[:-4] + "Z" | fromdateiso8601; map(.at | katip_timestamp_to_iso8601) | .[1] - .[0]')
  highwater=$(cat $input/highwater | cut -d' ' -f6)

  if [ -f $input/nix-support/custom-failed ]; then
    export PASS=false
    mkdir $out/nix-support -p
    cp $input/nix-support/custom-failed $out/nix-support/custom-failed
  else
    export PASS=true
  fi

  jq '
    def minavgmax:
        length as $len
      | { min: (min/1024/1024)
        , avg: ((add / $len)/1024/1024)
        , max: (max/1024/1024)
        };

      map(select(.ns[0] == "cardano.node.resources") | .data)
    | { RSS:          map(.RSS) | minavgmax
      , Heap:         map(.Heap) | minavgmax
      , CentiCpuMax:  map(.CentiCpu) | max
      , CentiMutMax:  map(.CentiMut) | max
      , SecGC:       (map(.CentiGC) | max / 100)
      , CentiBlkIO:   map(.CentiBlkIO) | max
      , flags:       "${flags}"
      , chain:       { startSlot: ${toString snapshot.snapshotSlot}
                     , stopFile:  ${toString snapshot.finalChunkNo}
                     }
      , totaltime:   '$totaltime'
      , pass:        '$PASS'
      }' --slurp input/summary.json > refined.json
''
