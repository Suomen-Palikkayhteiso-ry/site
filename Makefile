.PHONY:

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# ── Development environment ──────────────────────────────────────────────────

.PHONY: shell
shell: ## Enter devenv shell
	devenv shell

.PHONY: develop
develop: devenv.local.nix devenv.local.yaml ## Bootstrap opinionated development environment
	devenv shell --profile=devcontainer -- code .

devenv.local.nix:
	cp devenv.local.nix.example devenv.local.nix

devenv.local.yaml:
	cp devenv.local.yaml.example devenv.local.yaml

.PHONY: install
install: ## Install npm dependencies
	npm install

.PHONY: dev
dev: ## Start elm-pages dev server
	npx elm-pages dev

.PHONY: build
build: ## Build elm-pages site into dist/
	npx elm-pages build

.PHONY: deploy
deploy: ## Commit and push to trigger CI deploy (requires clean working tree)
	git push origin main

.PHONY: test
test: ## Run smoke test against SITE_URL
	bash scripts/smoke-test.sh
