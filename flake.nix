{
  inputs = {
    cardano-node-measured.url = "github:input-output-hk/cardano-node/1.33.0";
    cardano-node-measured.inputs.nixpkgs.follows = "cardano-node-measured/haskellNix/nixpkgs-2105"; ## WARNING:  update this to match the measured node

    cardano-node-snapshot.url = "github:input-output-hk/cardano-node/membench";
    cardano-node-snapshot.inputs.nixpkgs.follows = "cardano-node-measured/haskellNix/nixpkgs-2105";
    cardano-node-process.url = "github:input-output-hk/cardano-node/membench-report";
    cardano-node-process.inputs.nixpkgs.follows = "cardano-node-measured/haskellNix/nixpkgs-2105";
    ouroboros-network.url = "github:input-output-hk/ouroboros-network";
    ouroboros-network.flake = false;

    cardano-mainnet-mirror.url = "github:input-output-hk/cardano-mainnet-mirror/nix";
  };
  outputs = { ouroboros-network, self, nixpkgs, cardano-node-snapshot, cardano-node-process, cardano-node-measured, cardano-mainnet-mirror }@inputs: let
    network = import ouroboros-network { system = "x86_64-linux"; };
    params = builtins.fromJSON (builtins.readFile ./membench_params.json);
    rtsMemSize = null;
    rtsflags = params.rtsFlags;
    limit2 = "6553M";
    variantTable = {
      baseline = "";
      # justc = "-c";
      # four  = "-H4G -M${limit2}";
      # five  = "-H4G -M${limit2} -c50";
      # six   = "-H4G -M${limit2} -c70";
      #seven = "-H4G -M${limit2} -G3";
      #eight = "-H4G -M${limit2} -G3 -c50";
      #nine  = "-H4G -M${limit2} -G3 -c70";
    };
    overlay = self: super: {
      ## Do not let this overlay escape -- exposure to other flakes will break down due to inputs being inherited.
      inherit inputs;

      ## 0. Chain
      mainnet-chain = cardano-mainnet-mirror.defaultPackage.x86_64-linux;

      # TODO, fix this
      #db-analyser = network.haskellPackages.ouroboros-consensus-cardano.components.exes.db-analyser;

      ## 1. Ledger snapshot
      inherit cardano-node-snapshot;
      db-analyser = cardano-node-snapshot.packages.x86_64-linux.db-analyser;
      snapshot = self.callPackage ./snapshot-generation.nix
        { chain = self.mainnet-chain;
          shelleyGenesisHash = "1a3be38bcbb7911969283716ad7aa550250226b76a61fc51cc9a9a35d9276d81";
        };

      ## 2. Node under measurement
      cardano-node-measured = cardano-node-measured.packages.x86_64-linux.cardano-node;

      ## 3. Single run
      membench = self.callPackage ./membench.nix { inherit rtsflags rtsMemSize; };

      ## 4. Run batch:  profiles X iterations
      inherit cardano-node-process;
      batch = self.callPackage ./batch.nix { inherit variantTable; };

      ## 5. Data aggregation and statistics
      batch-results = self.callPackage ./batch-process.nix {};

      ## 6. Report generation
      batch-report = self.callPackage ./batch-report.nix {};
    };
  in {
    packages.x86_64-linux = let
      pkgs = import nixpkgs { system = "x86_64-linux"; overlays = [ overlay ]; };
    in {
      inherit (pkgs) mainnet-chain db-analyser snapshot membench batch batch-results batch-report;
    };
    hydraJobs.x86_64-linux = nixpkgs.lib.fix (s: {
      inherit (self.packages.x86_64-linux) snapshot batch-results batch-report;

      batch = self.packages.x86_64-linux.batch.override { nIterations = 5; };
    });
  };
}
