# K8s Playground - GitOps with Flux CD

A GitOps-based Kubernetes playground demonstrating automated deployment and management using Flux CD, with team-based job queues powered by Kueue.

## Local Setup with k3d

### Prerequisites

- [k3d](https://k3d.io/v5.4.6/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [flux CLI](https://fluxcd.io/flux/installation/)
- GitHub personal access token with repo permissions

### 1. Create Local Cluster

```bash
# Create a k3d cluster
k3d cluster create k3s-default

# Verify cluster is ready
kubectl cluster-info
```

### 2. Bootstrap Flux CD

Fork this repository to your GitHub account, then bootstrap Flux:

```bash
# Set your GitHub details
export GITHUB_USER=<your-github-username>
export GITHUB_TOKEN=<your-personal-access-token>

# Bootstrap Flux (replace <your-username> with your GitHub username)
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=k8splay \
  --branch=main \
  --path=./clusters/local \
  --personal
```

This will:
- Install Flux CD components in your cluster
- Create/update the GitHub repository with Flux configurations
- Set up GitOps automation to monitor `./clusters/local`
- Deploy all infrastructure components automatically

### 3. Verify Deployment

Wait for Flux to sync and deploy all components:

```bash
# Check Flux system
kubectl get pods -n flux-system

# Check infrastructure deployments
kubectl get pods -n nvidia-gpu-operator-system  # GPU operator (if applicable)
kubectl get pods -n kueue-system                # Kueue job scheduler

# Check team resources
kubectl get queues -n core-team                 # Team queues
kubectl get resourceflavors                     # Resource definitions
```

### 4. Generate Team Kubeconfig

Generate a kubeconfig for job submission:

```bash
# Make script executable
chmod +x scripts/generate-team-kubeconfig.sh

# Generate kubeconfig for core-team
./scripts/generate-team-kubeconfig.sh core-team

# This creates: core-team-kubeconfig.yaml
```

### 5. Test Job Submission

Use the generated kubeconfig to submit jobs:

```bash
# Set kubeconfig
export KUBECONFIG=$PWD/core-team-kubeconfig.yaml

# Create a test job
kubectl create job test-job --image=busybox -- echo 'Hello from core-team!'

# Add queue label for Kueue
kubectl patch job test-job --type=merge -p '{"spec":{"template":{"metadata":{"labels":{"kueue.x-k8s.io/queue-name":"core-general-queue"}}}}}'

# Monitor job status
kubectl get jobs
kubectl get pods
kubectl logs job/test-job
```

## Architecture Overview

This playground implements:

- **GitOps Workflow**: Flux CD monitors this repository and automatically deploys changes
- **Team-based Queues**: Kueue manages job scheduling with resource quotas per team
- **RBAC Security**: Team-specific ServiceAccounts with scoped permissions for job management
- **GPU Support**: NVIDIA GPU Operator for accelerated workloads (configurable)

### Directory Structure

```
├── clusters/local/                    # Local environment configuration
│   ├── flux-system/                   # Flux CD configuration
│   ├── kueue/                         # Kueue job scheduler overlay
│   ├── nvidia-gpu-operator/           # GPU operator overlay  
│   └── team-queues/                   # Team-based queue management
│       ├── resource-flavors/          # CPU and GPU resource definitions
│       ├── cluster-queues/            # Cluster-wide queue configuration
│       └── local-queues/core-team/    # Team-specific local queues
├── infrastructure/                    # Base infrastructure definitions
│   ├── kueue/                         # Kueue base configuration
│   └── nvidia-gpu-operator/           # GPU operator base configuration
└── scripts/                           # Utility scripts
    └── generate-team-kubeconfig.sh    # Generate team kubeconfigs
```

## Adding New Teams

1. Copy the `clusters/local/team-queues/local-queues/core-team/` directory
2. Update team name in all manifests
3. Commit changes - Flux will automatically deploy the new team resources

## Cleanup

```bash
# Delete the k3d cluster
k3d cluster delete k3s-default

# Remove generated kubeconfigs
rm *-kubeconfig.yaml
```

## Documentation

See [CLAUDE.md](./CLAUDE.md) for detailed architecture, components, and development guidelines.

## Contributing

This is a playground repository for learning GitOps patterns. Feel free to fork and experiment!