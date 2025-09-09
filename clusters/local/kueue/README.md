# Team Queues

This directory contains Kueue queue configurations for team-based workload management in the local cluster.

## Structure

```
team-queues/
├── resource-flavors/       # Shared resource definitions (CPU, GPU)
├── cluster-queues/         # Team-level resource pools
├── local-queues/           # Team-specific namespaced queues
│   └── core-team/         # Example team
├── validate-queues.sh      # Validation script
└── README.md              # This file
```

## Quick Start

### Validate Existing Setup
```bash
# Test the core team setup
./validate-queues.sh core-team
```

### Submit a Job
```bash
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: my-job
  namespace: core-team
  labels:
    kueue.x-k8s.io/queue-name: core-general-queue
spec:
  template:
    spec:
      containers:
      - name: worker
        image: busybox
        command: ["echo", "Hello from core team!"]
      restartPolicy: Never
EOF
```

## Available Teams

Run `./validate-queues.sh` without arguments to see available teams.

Current teams:
- **core-team**: Full access to all cluster resources

## Adding New Teams

### 1. Create team cluster queue in `cluster-queues/`:
```yaml
# {team-name}-cluster-queue.yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: {team-name}-cluster-queue
spec:
  namespaceSelector: {}
  resourceGroups:
  - coveredResources: ["cpu", "memory"]
    flavors:
    - name: cpu-flavor
      resources:
      - name: "cpu"
        nominalQuota: 50  # Adjust as needed
      - name: "memory"
        nominalQuota: 200Gi  # Adjust as needed
  - coveredResources: ["nvidia.com/gpu"]
    flavors:
    - name: gpu-flavor
      resources:
      - name: "nvidia.com/gpu"
        nominalQuota: 4  # Adjust as needed
  queueingStrategy: BestEffortFIFO
  preemption:
    reclaimWithinCohort: Any
    withinClusterQueue: LowerPriority
```

### 2. Create team directory in `local-queues/`:
```
local-queues/{team-name}/
├── {team-name}-namespace.yaml
├── {team-name}-general-queue.yaml
├── {team-name}-gpu-queue.yaml  # Optional
└── kustomization.yaml
```

### 3. Create namespace:
```yaml
# {team-name}-namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: {team-name}
  labels:
    team: {team-name}
```

### 4. Create local queues:
```yaml
# {team-name}-general-queue.yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  name: {team-name}-general-queue
  namespace: {team-name}
spec:
  clusterQueue: {team-name}-cluster-queue
```

### 5. Update kustomization files:
- Add cluster queue to `cluster-queues/kustomization.yaml`
- Add team directory to main `team-queues/kustomization.yaml`

## Usage Examples

### Submit job to core team general queue:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: example-job
  namespace: core-team
  labels:
    kueue.x-k8s.io/queue-name: core-general-queue
spec:
  template:
    spec:
      containers:
      - name: example
        image: busybox
        command: ["sleep", "30"]
      restartPolicy: Never
```

### Submit GPU job to core team:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: gpu-job
  namespace: core-team
  labels:
    kueue.x-k8s.io/queue-name: core-gpu-queue
spec:
  template:
    spec:
      containers:
      - name: gpu-task
        image: nvidia/cuda:11.8-runtime-ubuntu20.04
        resources:
          requests:
            nvidia.com/gpu: 1
          limits:
            nvidia.com/gpu: 1
        command: ["nvidia-smi"]
      restartPolicy: Never
```

## Validation

The `validate-queues.sh` script tests:
- ✅ ResourceFlavors exist
- ✅ ClusterQueue is configured
- ✅ Team namespace exists  
- ✅ LocalQueues are available
- ✅ Jobs can be submitted and completed
- ✅ Workload management is working

Usage:
```bash
./validate-queues.sh <team-name>
```

## Queue Types

Each team typically has:
- **General queue**: For CPU-based workloads
- **GPU queue**: For GPU-accelerated workloads (optional)

## Resource Management

- **ResourceFlavors**: Define node requirements (CPU vs GPU nodes)
- **ClusterQueues**: Set team-level resource quotas  
- **LocalQueues**: Provide namespace-scoped job submission points