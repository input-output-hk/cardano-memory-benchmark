all:  help

.PHONY: help batch

help: ## Print documentation
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

batch: ## Run a survey batch of benchmarks: 5 runs of each entry in the variantTable
	nix build .#batch

results: ## Same as batch, but also aggregate and do statistical processing
	nix build .#batch-results

report: ## Same as report, but also produce a report
	nix build .#batch-report

bump-node-process: ## Update the node version used for analysis
	nix flake lock update-input cardano-node-process

bump-node-measured: ## Update the node version under measurement
	nix flake lock update-input cardano-node-measured
