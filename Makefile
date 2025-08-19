sample:
	make sample-standalone-no-crds

sample-standalone-no-crds:
	helm upgrade --install \
		--create-namespace \
		-n d3e-sample \
		-f sample-configs/standalone-no-crds.yaml \
		d3e-sample .

d3e: d3e-standalone

# This is the default d3e deployment - no CRDs and no cluster roles.
d3e-standalone:
	helm upgrade --install \
		--skip-crds \
		--create-namespace \
		-n d3e-sample \
		-f d3e-configs/standalone-no-crds.yaml \
		dapr oci://public.ecr.aws/diagrid/d3e-charts/d3e-dapr --version 1.15.6-d3e.1

uninstall:
	make uninstall-d3e
	make uninstall-sample

uninstall-sample:
	helm uninstall d3e-sample -n d3e-sample

uninstall-d3e:
	helm uninstall dapr -n d3e-sample