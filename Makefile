infra:
	sh scripts/init.sh

nuke:
	sh scripts/nuke.sh

sample:
	helm install \
		--create-namespace \
		-n d3e-sample \
		d3e-sample .

d3e: d3e-standalone

d3e-minimal:
	helm install \
		--create-namespace \
		-n d3e-sample \
		-f d3e-configs/minimal-crds.yaml \
		dapr oci://public.ecr.aws/diagrid/d3e-charts/d3e-dapr --version 1.15.5

d3e-standalone:
	helm install \
		--skip-crds \
		--create-namespace \
		-n d3e-sample \
		-f d3e-configs/standalone-no-crds.yaml \
		dapr oci://public.ecr.aws/diagrid/d3e-charts/d3e-dapr --version 1.15.5

uninstall:
	make uninstall-d3e
	make uninstall-sample

uninstall-sample:
	helm uninstall d3e-sample -n d3e-sample

uninstall-d3e:
	helm uninstall dapr -n d3e-sample