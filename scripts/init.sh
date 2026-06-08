#!/bin/bash

echo "Initializing D3E sample infra"

docker run -d -p 5000:5000 --restart=always --name registry registry:2

kind create cluster --name d3e-sample

kubectl create namespace d3e-sample

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type "json" -p '[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

helm repo add valkey https://valkey.io/valkey-helm/ || true
helm upgrade --install valkey valkey/valkey -n d3e-sample \
	--set replica.enabled=false \
	--set auth.enabled=false