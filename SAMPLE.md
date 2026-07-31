# D3E Sample Application Guide

This guide demonstrates how to run the Diagrid D3E (Dapr) sample application, which showcases a publisher-subscriber pattern using Redis as the backing store.

## Overview

The sample application consists of:
- **Publisher Service** (`service-pub`): Publishes messages to a Redis pub/sub topic every 5 seconds
- **Subscriber Service** (`service-sub`): Subscribes to the topic and stores received messages in Redis state store
- **Redis**: Used for both pub/sub messaging and state storage
- **D3E Control Plane**: Manages the Dapr runtime and components

## Prerequisites

Before running the sample, ensure you have the following installed:

- [Docker](https://docs.docker.com/get-docker/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/) (Kubernetes in Docker)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)

## Quick Start

### 1. Initialize Infrastructure

Set up the local Kubernetes cluster and required infrastructure:

```bash
make infra
```

This command runs `scripts/init.sh` which:
- Starts a local Docker registry on port 5000
- Creates a Kind cluster named `d3e-sample`
- Creates the `d3e-sample` namespace
- Installs and configures the Kubernetes metrics server

### 2. Install D3E Control Plane

Install the D3E (Dapr) control plane with specific configurations:

```bash
make d3e
```

This command installs D3E in standalone mode (no CRDs required) with the following key settings:
- **Namespace**: `d3e-sample`
- **Mode**: Standalone (no CRDs required)
- **mTLS**: Enabled for secure communication
- **RBAC**: Namespaced permissions only
- **Actors**: Disabled (not needed for this sample)
- **Scheduler**: Disabled (not needed for this sample)

#### Alternative D3E Configurations

The project includes several D3E configuration templates in the `d3e-configs/` directory:

- **`make d3e-standalone`** (default): Namespaced RBAC, no CRDs - perfect for restricted environments
- **`make d3e-minimal`**: Cluster-wide RBAC with CRDs - for development/production with full permissions
- **`make d3e-with-crds-no-cluster-roles`**: Hybrid approach with CRDs but namespaced RBAC

See `d3e-configs/README.md` for detailed configuration comparisons and usage guidelines.

### 3. Deploy the Sample Application

Deploy the publisher and subscriber services:

```bash
make sample
```

This command installs the Helm chart with:
- Publisher service (`service-pub`) that publishes messages every 5 seconds
- Subscriber service (`service-sub`) that receives and stores messages
- Redis for pub/sub and state storage
- Dapr components (pubsub, statestore, secret store)

## Understanding the Sample

### Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   service-pub   │───▶│   Redis Pub/Sub │───▶│   service-sub   │
│   (Publisher)   │    │                 │    │   (Subscriber)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   Redis State   │
                       │     Store       │
                       └─────────────────┘
```

### Publisher Service (`samples/pub/main.go`)

The publisher service:
- Connects to Dapr using the Go SDK
- Publishes messages every 5 seconds to the `pubsub` component
- Each message contains:
  - Unique ID (UUID)
  - Timestamp
  - Content with current time
- Runs an HTTP health check endpoint on port 8080

```go
// Key publishing logic
func (s *service) publish() error {
    msg := message{
        ID:        uuid.New().String(),
        Timestamp: time.Now(),
        Content:   fmt.Sprintf("Message published at %s", time.Now().Format(time.RFC3339)),
    }
    // Publish to Redis via Dapr
    err := s.client.PublishEvent(context.Background(), pubsubName, topic, msgBytes)
    return err
}
```

### Subscriber Service (`samples/sub/main.go`)

The subscriber service:
- Subscribes to the `pubsub` topic
- Processes incoming messages
- Stores each message in the Redis state store using the message ID as the key
- Logs all processing activities

```go
// Message handling
func (s *service) handleMessage(ctx context.Context, e *common.TopicEvent) (retry bool, err error) {
    // Parse message
    var msg message
    json.Unmarshal(jsonData, &msg)
    
    // Store in Redis state store
    key := msg.ID
    err = s.client.SaveState(ctx, "statestore", key, jsonData, nil)
    return false, nil
}
```

### Dapr Components

The sample uses several Dapr components:

1. **PubSub Component** (`resources/components/pubsub.yaml`):
   - Type: `pubsub.redis`
   - Connects to Redis for message queuing
   - Scoped to both publisher and subscriber services

2. **State Store Component** (`resources/components/statestore.yaml`):
   - Type: `state.redis`
   - Used by subscriber to persist received messages
   - Connects to the same Redis instance

3. **Secret Store** (`resources/components/kubernetessecretstore.yaml`):
   - Provides secure access to Redis credentials
   - Uses Kubernetes secrets for credential management

## Monitoring the Application

### Check Service Status

```bash
# Check all pods in the namespace
kubectl get pods -n d3e-sample

# Check services
kubectl get services -n d3e-sample

# Check Dapr components
kubectl get components -n d3e-sample
```

### View Logs

```bash
# Publisher logs
kubectl logs -f deployment/service-pub -n d3e-sample

# Subscriber logs
kubectl logs -f deployment/service-sub -n d3e-sample

# Redis logs
kubectl logs -f deployment/d3e-sample-redis-master -n d3e-sample
```

### Expected Behavior

1. **Publisher**: You should see logs like:
   ```
   Published message: 123e4567-e89b-12d3-a456-426614174000
   ```

2. **Subscriber**: You should see logs like:
   ```
   Processing message - ID: 123e4567-e89b-12d3-a456-426614174000, Timestamp: 2024-01-15T10:30:00Z, Content: Message published at 2024-01-15T10:30:00Z
   Successfully processed message: 123e4567-e89b-12d3-a456-426614174000
   ```

### Access Redis Data

```bash
# Port forward to Redis
kubectl port-forward svc/d3e-sample-redis-master 6379:6379 -n d3e-sample

# Connect to Redis CLI (in another terminal)
redis-cli

# List all keys (messages stored by subscriber)
KEYS *

# Get a specific message
GET "123e4567-e89b-12d3-a456-426614174000"
```

## Configuration Details

### Helm Values (`values.yaml`)

Key configuration points:

```yaml
# D3E Control Plane Configuration
dapr:
  image:
    tag: "1.16.14-d3e.5"
  controlPlaneNamespace: "d3e-sample"

# Publisher Service Annotations
podAnnotationsPub: 
  dapr.io/app-id: service-pub
  dapr.io/enabled: "true"
  dapr.io/app-port: "8080"

# Subscriber Service Annotations  
podAnnotationsSub: 
  dapr.io/app-id: service-sub
  dapr.io/enabled: "true"
  dapr.io/app-port: "8080"

# D3E Injector Configuration
diagrid_dapr_injector:
  mode: "standalone"
  injectDaprResources: true
  configurationFiles:
    - config.yaml
```

### Service Deployment (`templates/service-pub-deployment.yaml`)

The publisher deployment includes:
- Dapr sidecar injection
- Environment variables for Dapr ports
- Volume mounts for Dapr resources
- Health check endpoint

## Troubleshooting

### Common Issues

1. **Pods not starting**:
   ```bash
   kubectl describe pod <pod-name> -n d3e-sample
   ```

2. **Dapr sidecar issues**:
   ```bash
   kubectl logs <pod-name> -c daprd -n d3e-sample
   ```

3. **Redis connection issues**:
   ```bash
   kubectl logs deployment/d3e-sample-redis-master -n d3e-sample
   ```

### Cleanup

To completely remove the sample:

```bash
make uninstall
```

To destroy the entire infrastructure:

```bash
make nuke
```

## Next Steps

This sample demonstrates:
- Basic D3E/Dapr setup and configuration
- Publisher-subscriber pattern implementation
- State management with Redis
- Service-to-service communication via Dapr

To extend this sample, consider:
- Adding more complex message processing
- Implementing retry policies and circuit breakers
- Adding metrics and observability
- Implementing actor patterns
- Adding authentication and authorization

## Additional Resources

### Documentation
- [D3E Official Documentation](https://docs.diagrid.io/enterprise-dapr/d3e/)
- [Dapr Go SDK](https://github.com/dapr/go-sdk)
- [Dapr Components](https://docs.dapr.io/concepts/components-concept/)
- [Helm Charts](https://helm.sh/docs/)

## Workflow example (actors + scheduler)

The pub/sub sample above runs with actors and the scheduler disabled. Dapr
**workflows** need both: the workflow engine runs on the actor runtime and drives
all execution through scheduler-backed reminders. Durable timers and
delayed/scheduled workflow starts are fired by the scheduler, so with the
scheduler disabled workflows cannot progress at all.

`samples/order-processor` is the upstream
[dapr/quickstarts order-processor](https://github.com/dapr/quickstarts/tree/master/workflows/go/sdk/order-processor).
`workflow.go` and `models.go` are verbatim upstream; only `main.go` differs —
upstream is a console app that places one order and exits, which cannot run as a
Kubernetes Deployment, so this version registers the same workflow and activities
and serves HTTP instead.

### Run it

```bash
# 1. Build the sample image into the cluster (no registry needed)
make workflow-image-minikube      # or: make workflow-image-kind

# 2. Control plane with actors + scheduler, still CRD-free and ClusterRole-free
#    (the same config is what actor reminders and the Jobs API need)
export DIAGRID_TOKEN=<your token>
make d3e-scheduler

# 3. The workflow app (pub/sub services are disabled in this config)
make sample-workflows
```

### Exercise it

```bash
kubectl port-forward -n d3e-sample deploy/service-workflow 8080:8080

# Place an order
curl -X POST localhost:8080/orders -H 'Content-Type: application/json' \
  -d '{"item_name":"cars","quantity":1}'

# Check status
curl localhost:8080/orders/<id>

# Delayed start - stays PENDING until the scheduler fires it
curl -X POST 'localhost:8080/orders?delaySeconds=30' \
  -H 'Content-Type: application/json' -d '{"item_name":"computers","quantity":1}'

# Orders over $5000 wait for approval (an external event)
curl -X POST localhost:8080/orders -H 'Content-Type: application/json' \
  -d '{"item_name":"cars","quantity":2}'
curl -X POST localhost:8080/orders/<id>/approve
```

### Notes

- The `statestore` component needs `actorStateStore: "true"`. Actors, and
  therefore workflows, will not start without it.
- The injector library gates `DAPR_SCHEDULER_HOST_ADDRESS` behind
  `semverCompare ">=1.14.0" <tag>`, which is false for every D3E tag because
  `1.18.2-d3e.1` is a semver prerelease. The workflow config therefore sets
  `dapr.io/scheduler-host-address` explicitly; without it the sidecar gets no
  scheduler address and workflows hang.
- Set `pubsub.enabled=false` to run the workflow example on its own. The pub/sub
  sample images are amd64-only; build them multi-arch with `cd samples && make push`.
