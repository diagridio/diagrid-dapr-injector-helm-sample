# Diagrid Dapr Injector Helm Library Chart

## Overview

The Diagrid Dapr Injector is a Helm library chart designed to inject the Dapr sidecar into your Kubernetes application workloads (e.g., Deployments, StatefulSets). This chart is based on the [dapr/dapr](https://github.com/dapr/dapr) project but functions as a library chart rather than a standalone installation.

## Prerequisites

- Kubernetes cluster
- Helm 3.x

## Installation

This chart is not intended for standalone use. Instead, incorporate it as a dependency in your existing Helm charts.

### Step 1: Add the Dependency

In your Helm chart's `Chart.yaml` file, add the following dependency:

```yaml
dependencies:
  - name: diagrid-dapr-injector
    version: 1.0.0
    repository: oci://public.ecr.aws/diagrid/d3e-charts
    alias: diagrid_dapr_injector
```

Update your Helm chart:

```bash
helm dependency update
```

### Step 2: Configure Values

In your `values.yaml` file, add any necessary overrides for the injector:

```yaml
dapr:  
  image: 
    tag: "1.14.5"
  ha:
    enabled: true
  controlPlaneNamespace: dapr-system
  controlPlaneTrustDomain: cluster.local

podAnnotations:
  dapr.io/enabled: "true"
  dapr.io/app-id: "myapp"
  dapr.io/app-port: "5000"
```

### Step 3: Update Workload Templates

Modify your workload templates (e.g., `templates/deployment.yaml`) to include the Dapr sidecar:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-deployment
  labels:
    app: {{ .Release.Name }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
      annotations:
        {{ toYaml .Values.podAnnotations | nindent 8 | trim}}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
      {{ include "diagrid-dapr-injector.sidecar" (dict "podAnnotations" .Values.podAnnotations "helmCtx" .) | nindent 6 }}
      volumes:
        {{ include "diagrid-dapr-injector.volumes" . | nindent 8 }}
        {{- include "diagrid.dapr.resources-volumes" . | indent 6 }}
        {{- if .Values.diagrid_dapr_injector.injectDaprResources }}
        {{- include "diagrid.dapr.resources-volumes" (dict "podAnnotations" .Values.podAnnotations "helmCtx" .) | indent 6 }}
        {{- end }}
```

## Configuration

The default values are defined in the [templates/_helpers.tpl](diagrid-dapr-injector/templates/_helpers.tpl) file. Key configuration options include:

- `dapr.image`: Dapr sidecar image settings
- `dapr.controlPlaneNamespace`: Namespace for the Dapr control plane
- `dapr.controlPlaneTrustDomain`: Trust domain for the cluster
- `dapr.actors`: Actor service configuration
- `dapr.reminders`: Reminder service configuration
- `dapr.scheduler`: Scheduler settings
- `dapr.ha`: High availability settings
- `dapr.mtls`: mTLS configuration
- `dapr.prometheus`: Prometheus metrics settings
- `dapr.mode`: Dapr mode (standalone or kubernetes)
- `dapr.injectDaprResources`: Enable Dapr without CRDs
- `dapr.configurationFiles`: List of configuration files to be injected into the sidecar

For a complete list of configuration options, refer to the `templates/_helpers.tpl` file in the chart.

### Dapr without CRDs

This Helm library chart enables the use of Dapr without CRDs. To enable this feature, set the injectDaprResources flag to true in your values file:

```yaml
diagrid_dapr_injector:
  mode: "standalone"
  injectDaprResources: true
  configurationFiles:
    - config.yaml
```

In standalone mode, the injector automatically mounts Dapr configurations, components, HTTP endpoints, resiliencies, and subscriptions into the workload. To enable this, ensure that all necessary resource files are placed in `resources/{type}` and listed in your confifuration files listed:

```yaml
diagrid_dapr_injector:
  configurationFiles:
    - config.yaml
```

The injector then converts these files into ConfigMaps and mounts them into the Dapr sidecar via the `--config` and `--resources-path` arguments.

You need to manually create the required ConfigMaps in the same namespace as the workload. Below are examples of how to generate ConfigMaps for different Dapr resources using the dapr.resource template.

```yaml
{{- include "dapr.resource" (dict "namespace" .Release.Namespace "files" (.Files.Glob "resources/configurations/*") "name" "dapr-configurations") }}
---
{{- include "dapr.resource" (dict "namespace" .Release.Namespace "files" (.Files.Glob "resources/components/*") "name" "dapr-components") }}
---
{{- include "dapr.resource" (dict "namespace" .Release.Namespace "files" (.Files.Glob "resources/httpendpoints/*") "name" "dapr-httpendpoints") }}
---
{{- include "dapr.resource" (dict "namespace" .Release.Namespace "files" (.Files.Glob "resources/resiliencies/*") "name" "dapr-resiliencies") }}
---
{{- include "dapr.resource" (dict "namespace" .Release.Namespace "files" (.Files.Glob "resources/subscriptions/*") "name" "dapr-subscriptions") }}
```

#### Injecting App Services in Standalone Mode

When running daprd in standalone mode, app services must be explicitly injected, as this is typically handled by the Dapr operator in Kubernetes.

To ensure proper service discovery, the name resolution component in the global configuration must be set to target Kubernetes:

```yaml
nameResolution:
  component: kubernetes
``` 

After configuring name resolution, you need to define the necessary services using the following Helm template:

```yaml
{{- include "diagrid.dapr.service" (dict "appId" "APP_ID_A" "podAnnotations" .Values.podAnnotationsA "namespace" .Release.Namespace) }}
---
{{- include "diagrid.dapr.service" (dict "appId" "APP_ID_B" "podAnnotations" .Values.podAnnotationsB "namespace" .Release.Namespace) }}
```

Replace APP_ID with the appropriate application ID. This ensures that Dapr can correctly resolve and communicate with the injected services.

#### Kubernetes permissions in Non-Default Dapr namespaces

If your Dapr enabled apps are using components that fetch secrets from non-default namespaces, please follow this guide [here](https://docs.dapr.io/operations/components/component-secrets/#non-default-namespaces)


### Trust Anchors

Trust anchors are essential for verifying the authenticity of the Dapr control plane.

By default, this sidecar injector library does not require explicit trust anchor configuration when the Dapr control plane and the workload are in the same namespace. In this scenario, the sidecar injector automatically utilizes the default trust anchors for the control plane via the Kubernetes downward API.

However, manual configuration of trust anchors is necessary when the Dapr control plane operates in a different namespace than the workload.

In this situation, you must manually supply the trust anchors to the sidecar injector through the `dapr.trustAnchors` field in your values file or Helm command.

To retrieve the trust anchors from the Dapr control plane namespace within a Kubernetes cluster, run the following command:

```bash
kubectl get secret -n dapr-system dapr-trust-bundle -o jsonpath="{.data['ca\.crt']}" | base64 -d | tee /tmp/trust-anchors.crt
```

### Passing the Trust Anchors to the Dapr Sidecar Injector

If the workload is in a different namespace than the Dapr control plane, you can pass the trust anchors to the Dapr sidecar injector by setting the `dapr.trustAnchors` field in the `values.yaml` file:


```yaml
dapr:
  trustAnchors: |
    -----BEGIN CERTIFICATE-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5+1q1Qy9X/PvO8Vc0P9M
    ...
    -----END CERTIFICATE-----
```

Alternatively, you can pass the trust anchors via the Helm install/upgrade `set` command. For example, if you saved the trust anchors to a file `/tmp/trust-anchors.crt`, you can pass it to the Dapr sidecar injector as follows:

```bash
# also showing passing the image tag, custom control plane namespace, and the trust anchors from a file
helm template --set dapr.controlPlaneNamespace=dapr-system-3 --set "dapr.image.tag=1.14.4" --set-file dapr.trustAnchors=/tmp/trust-anchors.crt -n dapr-system-3 deploy-sample 
```

## Support

For issues, feature requests, or questions, please file an issue in the [GitHub repository](https://github.com/diagridio/diagrid-dapr-injector).

## Software License Agreement

By using D3E in your applications you are agreeing to comply with the Diagrid D3E Software License Agreement as described [here](https://diagrid.ws/d3e-eula).