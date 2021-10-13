{ runCommand, cardano-node, jq, snapshot, strace, util-linux, e2fsprogs, gnugrep, procps, time, hexdump, nodesrc, lib }:

let
  params = builtins.fromJSON (builtins.readFile ./membench_params.json);
  topology = { Producers = []; };
  flags = params.rtsFlags;
  topologyPath = builtins.toFile "topology.json" (builtins.toJSON topology);
  passMem = (builtins.fromJSON (builtins.readFile ./pass.json)).memSize;
  failMem = (builtins.fromJSON (builtins.readFile ./fail.json)).memSize;
  avgMem = (passMem+failMem) / 2;
  inVM = false;
  membench = runCommand "membench" {
    memSize = if (params.memSize == "auto") then avgMem else params.memSize;
    buildInputs = [ cardano-node jq strace util-linux procps time ];
    succeedOnFailure = true;
  } ''
    mkdir -pv $out/nix-support

    ${lib.optionalString inVM ''
    echo 0 > /tmp/xchg/in-vm-exit
    echo 42 > $out/nix-support/failed

    # never overcommit
    echo 2 > /proc/sys/vm/overcommit_memory
    ''}

    pwd
    free -m
    cp -r ${snapshot}/chain chain
    chmod -R +w chain

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
      ' ${nodesrc}/configuration/cardano/mainnet-config.json > config.json
    cp -v ${nodesrc}/configuration/cardano/*-genesis.json .
    command time -f %M -o $out/highwater cardano-node ${flags} run --database-path chain/ --config config.json --topology ${topologyPath} --shutdown-on-slot-synced 2000
    #sleep 600
    #kill -int $!
    pwd
    df -h
    free -m
    egrep 'ReplayFromSnapshot|ReplayedBlock|will terminate|Ringing the node shutdown|TookSnapshot|cardano.node.resources' log.json > $out/summary.json
    ls -ltrh chain/ledger/
    mv -vi log*json config.json $out/
    mv chain $out/
    rm $out/nix-support/failed
  '';
in
runCommand "membench-post-process" {
  buildInputs = [ jq hexdump ];
} ''
  ls -lh ${membench}
  cp -r ${membench} $out
  chmod -R +w $out
  cd $out
  # so the node wont get GC'd, and you could confirm the source it came from
  ln -s ${cardano-node}/bin/cardano-node .
  totaltime=$({ head -n1 log.json ; tail -n1 log.json;} | jq --slurp 'def katip_timestamp_to_iso8601: .[:-4] + "Z" | fromdateiso8601; map(.at | katip_timestamp_to_iso8601) | .[1] - .[0]')
  highwater=$(cat ${membench}/highwater | cut -d' ' -f6)

  if [ -f ${membench}/nix-support/failed ]; then
    export FAILED=true
    mkdir $out/nix-support -p
    cp ${membench}/nix-support/failed $out/nix-support/failed
  else
    export FAILED=false
  fi

  jq --slurp < summary.json 'def minavgmax: length as $len | { min: (min/1024/1024), avg: ((add / $len)/1024/1024), max: (max/1024/1024) }; map(select(.ns[0] == "cardano.node.resources") | .data) | { RSS: map(.RSS) | minavgmax, Heap: map(.Heap) | minavgmax, CentiCpuMax: map(.CentiCpu) | max, CentiMutMax: map(.CentiMut) | max, CentiGC: map(.CentiGC) | max, CentiBlkIO: map(.CentiBlkIO) | max, flags: "${flags}", chain: { startSlot: ${toString snapshot.snapshotSlot}, stopFile: ${toString snapshot.finalEpoch} }, totaltime:'$totaltime', failed:'$FAILED', memSize: ${toString membench.memSize} }' > refined.json
''
