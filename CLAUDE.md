# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a GitOps-based Kubernetes playground repository using Flux CD for automated deployment and management. The repository follows a structured approach to manage Kubernetes infrastructure using Helm charts and Kustomize overlays.

## Architecture

### Directory Structure
- `clusters/local/` - Cluster-specific configurations for local environment
  - `flux-system/` - Flux CD system configuration and sync settings
  - `kueue/` - Kueue job scheduling system overlay for local cluster
  - `nvidia-gpu-operator/` - NVIDIA GPU Operator overlay for local cluster
  - `team-queues/` - Team-based queue management system with resource flavors and local queues
    - `resource-flavors/` - CPU and GPU resource flavor definitions
    - `cluster-queues/` - Core team cluster queue configuration
    - `local-queues/core-team/` - Local queues for core team namespace
- `infrastructure/` - Base infrastructure component definitions
  - `kueue/` - Kueue job scheduling system (Helm repository, release, and namespace)
  - `nvidia-gpu-operator/` - NVIDIA GPU Operator (Helm repository, release, and namespace)

### GitOps Flow
The repository uses Flux CD for GitOps automation:
1. Flux monitors the `main` branch at `ssh://git@github.com/seemethere/k8splay`
2. Changes to `./clusters/local` are automatically synchronized to the cluster
3. Infrastructure components are defined in `infrastructure/` and referenced by cluster overlays

## Key Components

### Flux CD Configuration
- **GitRepository**: Points to this repository's main branch
- **Kustomization**: Syncs `./clusters/local` directory with 10-minute intervals
- **Auto-sync**: Enabled with pruning for removed resources

### NVIDIA GPU Operator
- Manages GPU workloads on Kubernetes nodes
- Enables driver installation, device plugin, monitoring, and node labeling
- Configured with containerd runtime and appropriate tolerations/node selectors
- Location: `infrastructure/nvidia-gpu-operator/`

### Kueue Job Scheduling
- Provides job queueing and resource management for batch workloads
- Version pinned to 0.13.3
- Configured to manage jobs without queue names and wait for pod readiness
- Supports batch/job framework integration
- Location: `infrastructure/kueue/`

### Team-Based Queue Management
- Comprehensive queue system with resource flavors for CPU and GPU workloads
- **Resource Flavors**: CPU and GPU flavor definitions for node targeting
- **Cluster Queues**: Core team cluster queue for resource allocation
- **Local Queues**: Team-specific local queues (core-general-queue, core-gpu-queue)
- **Namespace Management**: Dedicated core-team namespace for queue isolation
- Location: `clusters/local/team-queues/`

## Working with This Repository

### Initial Setup
This repository was bootstrapped using Flux CD with the following command:

```bash
GITHUB_TOKEN="<personal-access-token>" \
  flux bootstrap github \
    --owner="seemethere" \
    --repository="k8splay" \
    --branch=main \
    --path=./clusters/<cluster_name> \
    --personal
```

This command:
- Installs Flux CD components in the target Kubernetes cluster
- Creates/updates the GitHub repository with Flux system configurations
- Sets up GitOps automation to monitor the `./clusters/local` path
- Configures Flux to sync changes from the `main` branch
- Uses personal GitHub repository (vs organization)

### Making Changes
1. Infrastructure changes: Modify files in `infrastructure/` directories
2. Cluster-specific changes: Modify files in `clusters/local/` directories  
3. Flux will automatically detect and apply changes within 1-10 minutes

### Kustomize Pattern
Each component follows the pattern:
- `namespace.yaml` - Namespace definition
- `helm-repository.yaml` - Helm repository source
- `helm-release.yaml` - Helm release configuration
- `kustomization.yaml` - Kustomize resource list

Cluster overlays reference base infrastructure components and can add patches or additional configurations.

### Common Tasks
- **Add new component**: Create directory in `infrastructure/` with namespace, helm-repository, helm-release, and kustomization files
- **Cluster-specific config**: Create overlay in `clusters/local/` that references base infrastructure
- **Update component version**: Modify version in `helm-release.yaml`
- **Add cluster patches**: Use `patchesStrategicMerge` or `patches` in cluster overlay kustomization
- **Add new team queue**: Create team directory under `team-queues/local-queues/` with namespace, local queues, and kustomization
- **Add resource flavors**: Define new resource flavors in `team-queues/resource-flavors/` for specific node types or requirements
- **Configure cluster queues**: Modify cluster queue definitions in `team-queues/cluster-queues/` for resource allocation policies

## Development Notes
- No traditional build/test/lint commands - this is a declarative Kubernetes configuration repository
- Validation happens through Kubernetes API server when Flux applies changes
- Use `kubectl` or `flux` CLI tools to verify deployments and troubleshoot issues
- All Helm values are embedded in `helm-release.yaml` files rather than separate values files