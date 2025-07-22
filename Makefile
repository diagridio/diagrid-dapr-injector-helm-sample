infra:
	sh scripts/init.sh

nuke:
	sh scripts/nuke.sh

sample:
	helm install \
		--create-namespace \
		-n d3e-sample \
		d3e-sample .

d3e:
	helm install \
		--skip-crds \
		--create-namespace \
		-n d3e-sample \
		--set global.rbac.namespaced=true \
		--set global.rbac.injector.enabled=false \
		--set-json 'global.rbac.namespaces=["d3e-sample"]' \
		--set diagrid.token="THIS_IS_ANYTHING" \
		--set global.tag=1.15-alpha \
		--set dapr_operator.enabled=false \
		--set global.mtls.enabled=true \
		--set dapr_sidecar_injector.enabled=false \
		--set dapr_placement.mode=standalone \
		--set dapr_scheduler.mode=standalone \
		--set dapr_sentry.mode=standalone \
		--set global.actors.enabled=false \
		--set global.scheduler.enabled=false \
		--set dapr_sentry.injectDaprSystemConfig=true \
		--set dapr_config.dapr_config_chart_included=false \
		--set global.rbac.createTokenReviewerRole=false \
		--set global.rbac.createTokenReviewerRoleBinding=false \
		dapr oci://public.ecr.aws/diagrid/d3e-charts/d3e-dapr --version 1.15.5

uninstall:
	make uninstall-d3e
	make uninstall-sample

uninstall-sample:
	helm uninstall d3e-sample -n d3e-sample

uninstall-d3e:
	helm uninstall dapr -n d3e-sample