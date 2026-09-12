CHARTS := $(notdir $(patsubst %/,%,$(wildcard charts/*/)))
# Anchored on Chart.yaml so only real charts match, not examples/README.md.
EXAMPLES := $(sort $(dir $(wildcard charts/*/examples/*/Chart.yaml)))
README_GENERATOR_VERSION := 2.7.2
GENERATOR := npx --yes @bitnami/readme-generator-for-helm@$(README_GENERATOR_VERSION)
KUBECONFORM_VERSION := v0.8.0
UNITTEST_VERSION := v1.1.2
FIXTURE := tests/consumer

# Oldest supported, plus the current stable minors. The chart picks apiVersions
# through common.capabilities.*, so each of these can render differently.
KUBE_VERSIONS ?= 1.23.0 1.33.0 1.37.0

BUILD := build
SCHEMA_REGISTRY := https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master
CRD_REGISTRY := https://raw.githubusercontent.com/datreeio/CRDs-catalog/main

.PHONY: help deps lint readme readme-check schema schema-check package unittest template conform check clean

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

schema: ## Regenerate each chart's values.schema.json from values.yaml
	@for chart in $(CHARTS); do \
		yq '.exports.defaults // .' charts/$$chart/values.yaml > /tmp/values-flat.yaml; \
		yq -o=json '.exports.defaults // .' charts/$$chart/values.yaml > /tmp/values-flat.json; \
		cp charts/$$chart/README.md /tmp/README-throwaway.md; \
		$(GENERATOR) --values /tmp/values-flat.yaml --readme /tmp/README-throwaway.md \
			--schema charts/$$chart/values.schema.json >/dev/null; \
		python3 hack/schema-postprocess.py charts/$$chart/values.schema.json /tmp/values-flat.json; \
	done

schema-check: ## Verify values.schema.json matches values.yaml
	@for chart in $(CHARTS); do \
		yq '.exports.defaults // .' charts/$$chart/values.yaml > /tmp/values-flat.yaml; \
		yq -o=json '.exports.defaults // .' charts/$$chart/values.yaml > /tmp/values-flat.json; \
		cp charts/$$chart/README.md /tmp/README-throwaway.md; \
		$(GENERATOR) --values /tmp/values-flat.yaml --readme /tmp/README-throwaway.md \
			--schema /tmp/values.schema.json >/dev/null; \
		python3 hack/schema-postprocess.py /tmp/values.schema.json /tmp/values-flat.json; \
		diff -u charts/$$chart/values.schema.json /tmp/values.schema.json \
			|| { echo "charts/$$chart/values.schema.json is out of date, run: make schema"; exit 1; }; \
	done
	@echo "Value schemas are in sync"

package: deps ## Package every chart into build/
	@mkdir -p $(BUILD)
	@for chart in $(CHARTS); do helm package charts/$$chart --destination $(BUILD) >/dev/null; done

# helmet is a library chart, so it renders nothing on its own. The suites run
# against tests/consumer, a real application chart that includes helmet.app and
# helmet.notes, with the freshly packaged chart dropped in as its dependency.
unittest: package ## Run the helm-unittest suites
	@helm plugin list | grep -q unittest || { \
		echo "helm-unittest not installed. Run: helm plugin install https://github.com/helm-unittest/helm-unittest --version $(UNITTEST_VERSION)"; exit 1; }
	@mkdir -p $(FIXTURE)/charts && rm -f $(FIXTURE)/charts/*.tgz
	@cp $(BUILD)/helmet-*.tgz $(FIXTURE)/charts/
	@helm unittest $(FIXTURE)

# Renders each example against the LOCAL chart rather than the published one, by
# dropping the freshly packaged .tgz into the example's charts/ directory. Every
# template in charts/*/templates is an unrendered partial, so `helm lint` alone
# proves nothing: this is what actually executes them.
template: package ## Render every example at every supported Kubernetes version
	@rm -rf $(BUILD)/rendered && mkdir -p $(BUILD)/rendered
	@for example in $(EXAMPLES); do \
		name=$$(basename $$example); \
		chart=$$(echo $$example | cut -d/ -f2); \
		rm -rf $(BUILD)/ex/$$name && mkdir -p $(BUILD)/ex && cp -r $$example $(BUILD)/ex/$$name; \
		mkdir -p $(BUILD)/ex/$$name/charts && cp $(BUILD)/$$chart-*.tgz $(BUILD)/ex/$$name/charts/; \
		for kube in $(KUBE_VERSIONS); do \
			helm template rel $(BUILD)/ex/$$name --kube-version $$kube \
				> $(BUILD)/rendered/$$name-$$kube.yaml \
				|| { echo "FAILED: $$name at Kubernetes $$kube"; exit 1; }; \
			echo "  rendered $$name at $$kube ($$(grep -cE '^kind:' $(BUILD)/rendered/$$name-$$kube.yaml) resources)"; \
		done; \
	done
	@echo "All examples render"

# Validates the rendered manifests against the real Kubernetes API schemas, plus
# the CRD catalog for ServiceMonitor and PodMonitor.
conform: template ## Validate rendered manifests against Kubernetes schemas
	@command -v kubeconform >/dev/null || { \
		echo "kubeconform not found. Install it: https://github.com/yannh/kubeconform/releases/tag/$(KUBECONFORM_VERSION)"; exit 1; }
	@for kube in $(KUBE_VERSIONS); do \
		kubeconform -strict -summary \
			-kubernetes-version $$kube \
			-schema-location default \
			-schema-location '$(CRD_REGISTRY)/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
			$(BUILD)/rendered/*-$$kube.yaml \
			|| { echo "FAILED validation at Kubernetes $$kube"; exit 1; }; \
	done

check: lint readme-check schema-check unittest conform ## Run everything CI runs

clean: ## Remove build output and vendored dependencies
	@rm -rf $(BUILD) $(FIXTURE)/charts
	@for chart in $(CHARTS); do rm -rf charts/$$chart/charts; done
