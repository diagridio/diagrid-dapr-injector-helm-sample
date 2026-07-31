infra:
	sh scripts/init.sh

nuke:
	sh scripts/nuke.sh

require-diagrid-token:
	@test -n "$$DIAGRID_TOKEN" || (echo "ERROR: DIAGRID_TOKEN is required (export it locally or set the GitHub Actions secret DIAGRID_TOKEN)." && exit 1)

sample:
	make sample-standalone-no-crds

sample-minimal:
	helm install \
		--create-namespace \
		-n d3e-sample \
		-f sample-configs/minimal.yaml \
		d3e-sample .

sample-standalone-no-crds:
	helm install \
		--create-namespace \
		-n d3e-sample \
		-f sample-configs/standalone-no-crds.yaml \
		d3e-sample .

sample-with-crds-no-cluster-roles:
	helm install \
		--create-namespace \
		-n d3e-sample \
		-f sample-configs/d3e-with-crds-no-cluster-roles.yaml \
		d3e-sample .

d3e: d3e-standalone

# This is the default d3e deployment - no CRDs and no cluster roles.
d3e-standalone: require-diagrid-token
	helm install \
		--skip-crds \
		--create-namespace \
		-n d3e-sample \
		-f d3e-configs/standalone-no-crds.yaml \
		--set-string diagrid.token="$$DIAGRID_TOKEN" \
		dapr oci://public.ecr.aws/diagrid/d3e-charts/d3e-dapr --version 1.16.14-d3e.5

# This is the standalone d3e deployment with Sentry automountServiceAccountToken disabled.
d3e-standalone-sentry-automount-disabled: require-diagrid-token
	helm install \
		--skip-crds \
		--create-namespace \
		-n d3e-sample \
		-f d3e-configs/standalone-no-crds-automount-sentry-disabled.yaml \
		--set-string diagrid.token="$$DIAGRID_TOKEN" \
		dapr oci://public.ecr.aws/diagrid/d3e-charts/d3e-dapr --version 1.16.14-d3e.5

# D3E minimal uses CRDs and minimal cluster roles
d3e-minimal: require-diagrid-token
	helm install \
		--create-namespace \
		-n d3e-sample \
		-f d3e-configs/minimal-with-crds.yaml \
		--set-string diagrid.token="$$DIAGRID_TOKEN" \
		dapr oci://public.ecr.aws/diagrid/d3e-charts/d3e-dapr --version 1.16.14-d3e.5

d3e-with-crds-no-cluster-roles: require-diagrid-token
	helm install \
		--create-namespace \
		-n d3e-sample \
		-f d3e-configs/d3e-with-crds-no-cluster-roles.yaml \
		--set-string diagrid.token="$$DIAGRID_TOKEN" \
		dapr oci://public.ecr.aws/diagrid/d3e-charts/d3e-dapr --version 1.16.14-d3e.5

uninstall:
	make uninstall-d3e
	make uninstall-sample

uninstall-sample:
	helm uninstall d3e-sample -n d3e-sample

uninstall-d3e:
	helm uninstall dapr -n d3e-sample

# ---------------------------------------------------------------------------
# Workflow sample (dapr/quickstarts order-processor)
# ---------------------------------------------------------------------------

ORDER_PROCESSOR_IMAGE ?= order-processor:latest
PLATFORMS ?= linux/amd64,linux/arm64
D3E_VERSION ?= 1.18.2-d3e.1

# Build the workflow sample image straight into the local cluster's daemon, so
# no registry is needed. Single-arch, matching whatever the cluster runs on.
workflow-image-minikube:
	minikube image build -t $(ORDER_PROCESSOR_IMAGE) samples/order-processor

workflow-image-kind:
	docker build -t $(ORDER_PROCESSOR_IMAGE) samples/order-processor
	kind load docker-image --name d3e-sample $(ORDER_PROCESSOR_IMAGE)

# Multi-arch build and push. Needs a docker-container buildx builder:
#   docker buildx create --name mabuilder --driver docker-container --use
workflow-image-push:
	docker buildx build --platform $(PLATFORMS) -t $(ORDER_PROCESSOR_IMAGE) --push samples/order-processor

# Control plane with actors + scheduler enabled (needed for workflows), still
# CRD-free and ClusterRole-free.
d3e-workflows: require-diagrid-token
	helm install \
		--skip-crds \
		--create-namespace \
		-n d3e-sample \
		-f d3e-configs/standalone-no-crds-workflows.yaml \
		--set-string diagrid.token="$$DIAGRID_TOKEN" \
		dapr oci://public.ecr.aws/diagrid/d3e-charts/d3e-dapr --version $(D3E_VERSION)

# Workflow sample app only (the pub/sub services are disabled in this config).
sample-workflows:
	helm install \
		--create-namespace \
		-n d3e-sample \
		-f sample-configs/standalone-no-crds-workflows.yaml \
		d3e-sample .
