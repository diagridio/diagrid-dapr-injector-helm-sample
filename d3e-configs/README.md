# D3E Configuration Templates

This directory contains template values files for different D3E deployment configurations. These templates help simplify the complex Helm values required for D3E deployments.

## Available Configurations

### 3. `standalone-no-crds.yaml` - Standalone Mode without CRDs
**Use case**: Restricted environments, multi-tenant clusters, or when you don't have cluster-admin privileges.

**Features**:
- ✅ Namespaced RBAC only (no cluster permissions)
- ✅ No CRDs required
- ✅ Standalone mode for all components
- ✅ Perfect for restricted environments

**Requirements**:
- Namespace-level permissions only
- No cluster-admin privileges needed

**Command**:
```bash
helm install dapr oci://public.ecr.aws/diagrid/d3e-charts/d3e-dapr \
  --version 1.15.6-d3e.1 \
  --create-namespace \
  -n d3e-sample \
  -f d3e-configs/standalone-no-crds.yaml
```

## Configuration Comparison

| Feature                   | standalone-no-crds |
|---------------------------|--------------------|
| Cluster Roles             | ❌                  |
| CRDs                      | ❌                  |
| Cluster Permissions       | Not Required       |
| Dapr Operator             | ❌                  |
| Sidecar Injector          | ❌                  |
| Standalone Mode           | ✅                  |
| Multi-tenant Safe         | ✅                  |
| Sentry Automount Disabled | ❌                  |


## Usage Instructions

### 1. Choose Your Configuration
Select the configuration that matches your environment and requirements.

### 2. Update the Token
Replace `YOUR_D3E_TOKEN_HERE` in the chosen configuration file with your actual D3E token.

### 3. Deploy D3E
Use the appropriate command from the configuration descriptions above.

### 4. Update Makefile (Optional)
You can update the Makefile to use these configuration files:

```makefile
d3e-standalone:
	helm install \
		--create-namespace \
		-n d3e-sample \
		-f d3e-configs/standalone-no-crds.yaml \
		dapr oci://public.ecr.aws/diagrid/d3e-charts/d3e-dapr --version 1.15.6-d3e.1
```

## Sample Application Configurations

The project also includes sample application configurations in `sample-configs/` that work with the D3E configurations:

- **`sample-configs/standalone-no-crds.yaml`**: Sample app config for standalone D3E (no cluster roles and no CRDs)

These are used by the Makefile commands:
- `make sample-standalone-no-crds`
 