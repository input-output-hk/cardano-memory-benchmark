all:  help

.PHONY: help membenches

help: ## Print documentation
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

membenches: ## Run a survey batch of benchmarks: 5 runs of each entry in the variantTable
	nix build .#membenches
