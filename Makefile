infra:
	sh scripts/init.sh

nuke:
	sh scripts/nuke.sh

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
d3e-standalone:
	helm install \
		--skip-crds \
		--create-namespace \
		-n d3e-sample \
		-f d3e-configs/standalone-no-crds.yaml \
		dapr oci://public.ecr.aws/diagrid/d3e-charts/d3e-dapr --version 1.15.5

# D3E minimal uses CRDs and minimal cluster roles
d3e-minimal:
	helm install \
		--create-namespace \
		-n d3e-sample \
		-f d3e-configs/minimal-with-crds.yaml \
		dapr oci://public.ecr.aws/diagrid/d3e-charts/d3e-dapr --version 1.15.5

d3e-with-crds-no-cluster-roles:
	helm install \
		--create-namespace \
		-n d3e-sample \
		-f d3e-configs/d3e-with-crds-no-cluster-roles.yaml \
		dapr oci://public.ecr.aws/diagrid/d3e-charts/d3e-dapr --version 1.15.5

uninstall:
	make uninstall-d3e
	make uninstall-sample

uninstall-sample:
	helm uninstall d3e-sample -n d3e-sample

uninstall-d3e:
	helm uninstall dapr -n d3e-sample