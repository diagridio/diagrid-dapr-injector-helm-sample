#!/bin/bash

echo "Nuking D3E sample infra"

kind delete cluster --name d3e-sample
docker rm -f registry
