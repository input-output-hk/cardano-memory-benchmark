{ runCommand, lib
, jq, snapshot, strace, util-linux, e2fsprogs, gnugrep, procps, time, hexdump
, cardano-node-snapshot, cardano-node-measured
, rtsflags, rtsMemSize, currentIteration ? null
, suffix ? ""
}:

let
  flags = "${rtsflags} ${lib.optionalString (rtsMemSize != null) "-M${rtsMemSize}"}";
  topology = { Producers = []; };
  topologyPath = builtins.toFile "topology.json" (builtins.toJSON topology);
  inVM = false;
  membench = runCommand "membench${suffix}" {
    outputs = [ "out" "chain" ];
    buildInputs = [ cardano-node-measured jq strace util-linux procps time ];
    succeedOnFailure = true;
    inherit currentIteration;
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
      ' ${cardano-node-snapshot}/configuration/cardano/mainnet-config.json > config.json
    cp -v ${cardano-node-snapshot}/configuration/cardano/*-genesis.json .
    command time -f %M -o $out/highwater cardano-node +RTS -s$out/rts.dump ${flags} -RTS run --database-path chain/ --config config.json --topology ${topologyPath} --shutdown-on-slot-synced 2000 2>$out/stderr
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
  '';
in
runCommand "membench-run-report${suffix}" {
  buildInputs = [ jq hexdump ];
  preferLocalBuild = true;
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
    export FAILED=true
    mkdir $out/nix-support -p
    cp $input/nix-support/custom-failed $out/nix-support/custom-failed
  else
    export FAILED=false
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
      , SecMutMax:   (map(.CentiMut) | max / 100)
      , SecGC:       (map(.CentiGC) | max / 100)
      , CentiBlkIO:   map(.CentiBlkIO) | max
      , flags:       "${flags}"
      , chain:       { startSlot: ${toString snapshot.snapshotSlot}
                     , stopFile:  ${toString snapshot.finalEpoch}
                     }
      , totaltime:   '$totaltime'
      , failed:      '$FAILED'
      }' --slurp input/summary.json > refined.json
''
