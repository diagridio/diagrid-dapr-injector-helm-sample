# D3E Configuration Templates

This directory contains template values files for different D3E deployment configurations. These templates help simplify the complex Helm values required for D3E deployments.

## Available Configurations

### 1. `minimal-crds.yaml` - Basic Deployment with CRDs
**Use case**: Development, testing, and production environments where you have cluster-admin privileges.

**Features**:
- ✅ Cluster-wide RBAC permissions
- ✅ CRDs enabled for full Dapr functionality
- ✅ Dapr operator and sidecar injector enabled
- ✅ Standard Kubernetes mode for all components

**Requirements**:
- Cluster-admin privileges (for CRD creation)
- Full cluster access

**Command**:
```bash
helm install dapr oci://public.ecr.aws/diagrid/d3e-charts/d3e-dapr \
  --version 1.15.5 \
  --create-namespace \
  -n d3e-sample \
  -f d3e-configs/minimal-crds.yaml
```

### 2. `standalone-no-crds.yaml` - Standalone Mode without CRDs
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
  --version 1.15.5 \
  --create-namespace \
  -n d3e-sample \
  -f d3e-configs/standalone-no-crds.yaml
```

## Configuration Comparison

| Feature | minimal-crds | standalone-no-crds | namespaced-with-crds |
|---------|--------------|-------------------|---------------------|
| Cluster RBAC | ✅ | ❌ | ❌ |
| CRDs | ✅ | ❌ | ✅ |
| Cluster Permissions | Required | Not Required | May be Required |
| Dapr Operator | ✅ | ❌ | ✅ |
| Sidecar Injector | ✅ | ❌ | ✅ |
| Standalone Mode | ❌ | ✅ | ❌ |
| Multi-tenant Safe | ❌ | ✅ | ⚠️ |

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
d3e-minimal:
	helm install \
		--create-namespace \
		-n d3e-sample \
		-f d3e-configs/minimal-crds.yaml \
		dapr oci://public.ecr.aws/diagrid/d3e-charts/d3e-dapr --version 1.15.5

d3e-standalone:
	helm install \
		--create-namespace \
		-n d3e-sample \
		-f d3e-configs/standalone-no-crds.yaml \
		dapr oci://public.ecr.aws/diagrid/d3e-charts/d3e-dapr --version 1.15.5
```

## Key Differences Explained

### CRDs vs No CRDs
- **With CRDs**: Full Dapr functionality, components defined as Kubernetes resources
- **Without CRDs**: Standalone mode, components defined via configuration files

### Cluster RBAC vs Namespaced RBAC
- **Cluster RBAC**: Can create cluster-wide resources, requires cluster-admin privileges
- **Namespaced RBAC**: Limited to namespace scope, safer for multi-tenant environments

### Standalone vs Kubernetes Mode
- **Standalone**: Components run independently, no operator required
- **Kubernetes**: Components managed by Dapr operator, full integration with K8s

## Troubleshooting

### Common Issues

1. **CRD Creation Fails**: You need cluster-admin privileges
   - Solution: Use `standalone-no-crds.yaml`

2. **RBAC Permission Denied**: Namespaced configuration doesn't have enough permissions
   - Solution: Use `minimal-crds.yaml` or contact cluster admin

3. **Components Not Starting**: Check if the configuration matches your environment
   - Solution: Verify token and namespace settings

### Validation Commands

```bash
# Check if CRDs are installed
kubectl get crd | grep dapr

# Check RBAC resources
kubectl get clusterrole,clusterrolebinding | grep dapr

# Check namespace resources
kubectl get role,rolebinding -n d3e-sample | grep dapr
``` 