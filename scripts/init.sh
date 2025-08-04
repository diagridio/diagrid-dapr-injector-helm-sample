#!/bin/bash

echo "Initializing D3E sample infra"

docker run -d -p 5000:5000 --restart=always --name registry registry:2

kind create cluster --name d3e-sample

kubectl create namespace d3e-sample

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type "json" -p '[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

helm install redis oci://registry-1.docker.io/bitnamicharts/redis --version 18.16.1 -n d3e-sample --set architecture=standalone --set master.persistence.enabled=false --set master.persistence.size=20Mi