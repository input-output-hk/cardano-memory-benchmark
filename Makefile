all:  help

.PHONY: help batch

SUBSTITUTERS_DEPS  ?= https://cache.nixos.org https://hydra.iohk.io
SUBSTITUTERS_ALL = $(SUBSTITUTERS_DEPS)
FLAGS_BASE = --option substituters "$(SUBSTITUTERS_ALL)"
FLAGS_BENCH = $(FLAGS_BASE) --max-jobs 1
FLAGS_LOCAL_MEASURE = ${FLAGS_BENCH} --override-input cardano-node-measured git+file://${CARDANO_NODE}
FLAGS_LOCAL_PROCESS = ${FLAGS_BENCH} --override-input cardano-node-process  git+file://${CARDANO_NODE}

CARDANO_NODE ?= ${HOME}/cardano-node

help: ## Print documentation
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

batch-prebuild: ## Fast, parallel prebuild of batch dependencies: NOT FOR BENCHMARKING
	nix build .#hydraJobs.x86_64-linux.batch-1            ${FLAGS_BASE} --max-jobs 8 -o batch-1

batch: ## Run a survey batch of benchmarks: 5 runs of each entry in the variantTable
	nix build .#hydraJobs.x86_64-linux.$@                 ${FLAGS_BENCH} -o $@

batch-results: ## Run a batch, then perform result analysis
	nix build .#hydraJobs.x86_64-linux.$@                 ${FLAGS_BENCH} -o $@

batch-report: ## Run a batch, analyse and produce a Hydra report
	nix build .#hydraJobs.x86_64-linux.$@                 ${FLAGS_BENCH} -o $@

batch-1: ## A single-round benchmark run
	nix build .#hydraJobs.x86_64-linux.$@                 ${FLAGS_BENCH} -o $@

batch-locm-report: ## Like batch, but measure node checkout in $CARDANO_NODE
	nix build .#hydraJobs.x86_64-linux.batch-report       ${FLAGS_LOCAL_MEASURE} -o batch-report

batch-locm-1: ## Like batch-local, but just a single run
	nix build .#hydraJobs.x86_64-linux.batch-1            ${FLAGS_LOCAL_MEASURE} -o batch-1

batch-locr-results: ## Like batch-results, but use local node checkout in $CARDANO_NODE for processing
	nix build .#hydraJobs.x86_64-linux.batch-results      ${FLAGS_LOCAL_PROCESS} -o batch-results

batch-locr-report: ## Like batch-report, but use local node checkout in $CARDANO_NODE for processing
	nix build .#hydraJobs.x86_64-linux.batch-report       ${FLAGS_LOCAL_PROCESS} -o batch-report

flake-bump-snapshot:
	nix flake lock --update-input cardano-node-snapshot

flake-bump-measure:
	nix flake lock --update-input cardano-node-measure

flake-bump-process:
	nix flake lock --update-input cardano-node-process

reflake: ## Regenerate the flake.lock
	nix flake show --option allow-import-from-derivation true

cls:
	echo -en "\ec"
