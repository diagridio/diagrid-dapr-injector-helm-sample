#!/bin/bash

echo "Nuking D3E sample infra"

kubectl delete crd components.dapr.io configurations.dapr.io configurations.dapr.io httpendpoints.dapr.io resiliencies.dapr.io subscriptions.dapr.io

kind delete cluster --name d3e-sample
docker rm -f registry
