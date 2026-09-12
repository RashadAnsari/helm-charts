CHARTS := $(notdir $(patsubst %/,%,$(wildcard charts/*/)))
README_GENERATOR_VERSION := 2.7.2
GENERATOR := npx --yes @bitnami/readme-generator-for-helm@$(README_GENERATOR_VERSION)

.PHONY: help deps lint readme readme-check check

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-13s\033[0m %s\n", $$1, $$2}'

deps: ## Build chart dependencies
	@for chart in $(CHARTS); do helm dependency build charts/$$chart; done

lint: deps ## Lint every chart
	@for chart in $(CHARTS); do helm lint charts/$$chart; done

# The generator reads @param annotations from values.yaml. Library charts nest
# their values under exports.defaults, so the subtree is extracted first.
readme: ## Regenerate each chart's parameter table from values.yaml
	@for chart in $(CHARTS); do \
		yq '.exports.defaults // .' charts/$$chart/values.yaml > /tmp/values-flat.yaml; \
		$(GENERATOR) --values /tmp/values-flat.yaml --readme charts/$$chart/README.md; \
	done

# Regenerates into a scratch copy so the working tree is left untouched, which
# means this reports real drift rather than any uncommitted edit.
readme-check: ## Verify parameter tables match values.yaml
	@for chart in $(CHARTS); do \
		yq '.exports.defaults // .' charts/$$chart/values.yaml > /tmp/values-flat.yaml; \
		cp charts/$$chart/README.md /tmp/README-expected.md; \
		$(GENERATOR) --values /tmp/values-flat.yaml --readme /tmp/README-expected.md; \
		diff -u charts/$$chart/README.md /tmp/README-expected.md \
			|| { echo "charts/$$chart/README.md is out of date, run: make readme"; exit 1; }; \
	done
	@echo "Parameter tables are in sync"

check: lint readme-check ## Run everything CI runs
