sample:
	make sample-standalone-no-crds

sample-standalone-no-crds:
	helm upgrade --install \
		--create-namespace \
		-n d3e-sample \
		-f sample-configs/standalone-no-crds-no-sentry.yaml \
		d3e-sample .

uninstall:
	make uninstall-sample

uninstall-sample:
	helm uninstall d3e-sample -n d3e-sample
