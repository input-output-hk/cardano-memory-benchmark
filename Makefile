all:  help

.PHONY: help batch

SUBSTITUTERS_DEPS  ?= https://cache.nixos.org https://hydra.iohk.io
SUBSTITUTERS_ALL = $(SUBSTITUTERS_DEPS)

help: ## Print documentation
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

batch-parallel: ## Parallel build of batch: NOT FOR BENCHMARKING
	nix build .#batch --option substituters "$(SUBSTITUTERS_ALL)" --max-jobs 8

batch: ## Run a survey batch of benchmarks: 5 runs of each entry in the variantTable
	nix build .#batch --option substituters "$(SUBSTITUTERS_ALL)" --max-jobs 1

results: ## Same as batch, but also aggregate and do statistical processing
	nix build .#batch-results

report: ## Same as report, but also produce a report
	nix build .#batch-report

bump-node-process: ## Update the node version used for analysis
	nix flake lock update-input cardano-node-process

bump-node-measured: ## Update the node version under measurement
	nix flake lock update-input cardano-node-measured

reflake:
	nix flake show --option allow-import-from-derivation true
