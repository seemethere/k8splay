# Team Queue Template

This template shows how to create queue configurations for new teams based on the core team structure.

## Core Team Structure (Reference)

```
team-queues/
├── resource-flavors/           # Shared resource definitions
│   ├── cpu-flavor.yaml
│   ├── gpu-flavor.yaml
│   └── kustomization.yaml
├── cluster-queues/             # Team cluster queues
│   ├── core-team-cluster-queue.yaml
│   └── kustomization.yaml
├── local-queues/               # Team-specific local queues
│   └── core-team/
│       ├── core-team-namespace.yaml
│       ├── core-general-queue.yaml
│       ├── core-gpu-queue.yaml
│       └── kustomization.yaml
└── kustomization.yaml
```

## Adding a New Team

1. **Create team cluster queue** in `cluster-queues/`:
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

2. **Create team directory** in `local-queues/`:
   ```
   local-queues/{team-name}/
   ├── {team-name}-namespace.yaml
   ├── {team-name}-general-queue.yaml
   ├── {team-name}-gpu-queue.yaml  # Optional
   └── kustomization.yaml
   ```

3. **Create namespace**:
   ```yaml
   # {team-name}-namespace.yaml
   apiVersion: v1
   kind: Namespace
   metadata:
     name: {team-name}
     labels:
       team: {team-name}
   ```

4. **Create local queues**:
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

5. **Update kustomization files**:
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