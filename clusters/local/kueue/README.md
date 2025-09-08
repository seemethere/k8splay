# Kueue Configuration

This directory contains the kueue configuration for the local cluster, providing users with a simple queue to launch jobs.

## Resources Created

The kueue system creates the following resources (defined in `/infrastructure/kueue/`):

1. **ResourceFlavor** (`default-flavor`): Defines the node characteristics and available resources
2. **ClusterQueue** (`cluster-queue`): Global queue with resource limits (10 CPU cores, 20GB memory)
3. **LocalQueue** (`user-queue`): User-accessible queue in the `kueue-user` namespace
4. **Namespace** (`kueue-user`): Dedicated namespace for user workloads

## Usage

### Submitting Jobs

Users can submit jobs to the queue by:

1. **Adding the queue label** to their Job manifests:
   ```yaml
   metadata:
     labels:
       kueue.x-k8s.io/queue-name: user-queue
     namespace: kueue-user
   ```

2. **Using the example job**:
   ```bash
   kubectl apply -f example-job.yaml
   ```

### Monitoring Jobs

Check job status:
```bash
# View jobs in the queue
kubectl get jobs -n kueue-user

# Check kueue workloads
kubectl get workloads -n kueue-user

# View queue status
kubectl get localqueue user-queue -n kueue-user -o yaml
kubectl get clusterqueue cluster-queue -o yaml
```

### Resource Limits

The current configuration provides:
- **CPU**: 10 cores total
- **Memory**: 20GB total
- **Queue Strategy**: BestEffortFIFO (first in, first out)

Jobs will be queued if they exceed available resources and will be scheduled when resources become available.

## Customization

To modify resource limits, edit `cluster-queue.yaml` and adjust the `nominalQuota` values for CPU and memory.

To add node selection criteria, modify `resource-flavor.yaml` with appropriate `nodeLabels` or `nodeTaints`.
