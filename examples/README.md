# Kubernetes Examples

This directory contains example Kubernetes configurations for the k8splay repository.

## StatefulSet with Kueue Integration

The `statefulset-with-queue.yaml` file demonstrates a Docker-in-Docker development workspace that integrates with the Kueue job scheduling system.

### Features

- **Docker-in-Docker**: Uses `docker:dind` image for containerized development
- **Persistent Storage**: 
  - `/home/dev` - 10Gi persistent volume for development files
  - `/var/lib/docker` - 20Gi persistent volume for Docker's graph storage
- **Kueue Integration**: Uses the `core-general-queue` from the core-team namespace
- **Scalable**: Can be scaled up/down based on demand

### Deployment

Deploy the StatefulSet using kubectl:

```bash
kubectl apply -f examples/statefulset-with-queue.yaml
```

### Scaling Operations

The StatefulSet can be dynamically scaled to match your development needs:

#### Scale Up (Start Development Environment)
```bash
# Scale to 1 replica when you need the development environment
kubectl scale statefulset dev-workspace -n core-team --replicas=1
```

#### Scale Down (Save Resources)
```bash
# Scale to 0 replicas when not in use to free up cluster resources
kubectl scale statefulset dev-workspace -n core-team --replicas=0
```

#### Multiple Developers
```bash
# Scale to multiple replicas for team development
kubectl scale statefulset dev-workspace -n core-team --replicas=3
```

### Benefits of Scaling

- **Resource Efficiency**: Scale down to 0 when not needed to free up CPU, memory, and GPU resources
- **Cost Optimization**: Only consume cluster resources when actively developing
- **Persistent Data**: Scaling down to 0 preserves all data in persistent volumes
- **Quick Startup**: Scaling back up restores your exact development environment
- **Kueue Integration**: All scaling operations respect the core-team's resource quotas and scheduling policies

### Accessing the Development Environment

Once deployed and scaled up, access your development workspace:

```bash
# Get pod name
kubectl get pods -n core-team -l app=dev-workspace

# Execute into the container
kubectl exec -it dev-workspace-0 -n core-team -- /bin/sh

# Check Docker is running
docker version
```

### Persistent Storage

Data persists across scaling operations:
- Your development files in `/home/dev` remain intact
- Docker images and containers in `/var/lib/docker` are preserved
- Configuration and state survive pod restarts and scaling events