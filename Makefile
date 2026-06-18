.PHONY: all ci fmt lint test quality bootstrap doctor help

all: ci

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

ci: fmt lint test quality

fmt: ## Run full quality gate
	@./scripts/quality_gate.sh

lint: ## Run LOC gate
	@./scripts/loc_gate.sh

test: ## Run BATS tests
	@if command -v bats &>/dev/null && [ -d tests ]; then \
		bats tests/*.bats; \
	else \
		echo "No bats or no tests directory"; \
	fi

quality: ## Run quality gate (skip hook check)
	@SKIP_GLOBAL_HOOKS_CHECK=true ./scripts/quality_gate.sh

bootstrap: ## Bootstrap the repo (skills, hooks, validation)
	@./scripts/bootstrap.sh

doctor: ## Run environment diagnostics
	@./scripts/doctor.sh

