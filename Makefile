.PHONY: all ci fmt lint test quality bootstrap doctor help cli clean-workspaces clean-local-caches

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

cli: ## Show CLI help
	@./bin/agent-toolkit help


clean-workspaces: ## Remove local skill eval workspaces and heavy local caches
	@find .agents/skills -maxdepth 1 -type d -name '*-workspace' -exec rm -rf {} + 2>/dev/null || true
	@rm -rf .agents/skills/*/node_modules 2>/dev/null || true
	@echo "Removed local skill workspaces (gitignored)."

clean-local-caches: clean-workspaces ## Also clear common local agent caches
	@rm -rf .mimocode/node_modules .opencode/node_modules 2>/dev/null || true
	@find . -type d -name '__pycache__' ! -path './.git/*' -exec rm -rf {} + 2>/dev/null || true
	@echo "Cleared local node_modules/__pycache__ under tooling dirs where safe."
