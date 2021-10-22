{
  inputs = {
    nixpkgs.follows = "cardano-node/haskellNix/nixpkgs-2105";
    cardano-node.url = "github:input-output-hk/cardano-node";
    cardano-node2.url = "github:input-output-hk/cardano-node/membench";
    ouroboros-network.url = "github:input-output-hk/ouroboros-network";
    ouroboros-network.flake = false;
    mainnet-chain.url = "github:input-output-hk/cardano-mainnet-mirror/shelley";
    mainnet-chain.flake = false;
  };
  outputs = { ouroboros-network, self, cardano-node, nixpkgs, cardano-node2, mainnet-chain }: let
    network = import ouroboros-network { system = "x86_64-linux"; };
    params = builtins.fromJSON (builtins.readFile ./membench_params.json);
    rtsMemSize = null;
    rtsflags = params.rtsFlags;
    limit2 = "6553M";
    variantTable = {
      baseline = "";
      justc = "-c";
      four  = "-H4G -M${limit2}";
      five  = "-H4G -M${limit2} -c50";
      six   = "-H4G -M${limit2} -c70";
      seven = "-H4G -M${limit2} -G3";
      eight = "-H4G -M${limit2} -G3 -c50";
      nine  = "-H4G -M${limit2} -G3 -c70";
    };
    overlay = self: super: {
      inherit mainnet-chain;
      nodesrc = cardano-node2;
      # TODO, fix this
      #db-analyser = network.haskellPackages.ouroboros-consensus-cardano.components.exes.db-analyser;
      db-analyser = cardano-node2.packages.x86_64-linux.db-analyser;
      snapshot = self.callPackage ./snapshot-generation.nix {};
      membench = self.callPackage ./membench.nix { inherit rtsflags rtsMemSize; };
      membenches = self.callPackage ./membenches.nix { inherit variantTable; };
      cardano-node = cardano-node.packages.x86_64-linux.cardano-node;
    };
  in {
    packages.x86_64-linux = let
      pkgs = import nixpkgs { system = "x86_64-linux"; overlays = [ overlay ]; };
    in {
      inherit (pkgs) snapshot db-analyser membench membenches;
    };
    hydraJobs.x86_64-linux.membenches = self.packages.x86_64-linux.membenches;
  };
}
