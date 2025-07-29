export KO_DOCKER_REPO=docker.io/nelsonparente00

push:
	ko publish ./pub
	ko publish ./sub

APP_NAMESPACE ?= d3e-sample
PUB_SERVICE_IMAGE = $(KO_DOCKER_REPO)/pub-service:latest
SUB_SERVICE_IMAGE = $(KO_DOCKER_REPO)/sub-service:latest

.PHONY: deploy
deploy:
	kubectl create namespace ${APP_NAMESPACE} | true
	make load-kind-images
	kubectl apply -f dapr/configuration.yaml -n ${APP_NAMESPACE}
	kubectl apply -f dapr/deploy -n ${APP_NAMESPACE}

nuke:
	kubectl delete namespace ${APP_NAMESPACE}

load-kind-images:
	docker pull --quiet ${PUB_SERVICE_IMAGE}
	docker pull --quiet ${SUB_SERVICE_IMAGE}
	kind load docker-image --name ${APP_NAMESPACE}  ${PUB_SERVICE_IMAGE}
	kind load docker-image --name ${APP_NAMESPACE}  ${SUB_SERVICE_IMAGE}

