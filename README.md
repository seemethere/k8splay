# k8splay

A GitOps-based Kubernetes playground repository using Flux CD for automated deployment and management.

## Overview

This repository demonstrates a production-ready GitOps workflow with:

- **Flux CD** for automated synchronization and deployment
- **Kueue** for job scheduling and resource management
- **NVIDIA GPU Operator** for GPU workload support
- **Team-based queue management** with resource flavors and local queues

## Architecture

```
├── clusters/local/          # Cluster-specific configurations
│   ├── flux-system/         # Flux CD system components
│   ├── kueue/               # Kueue overlay
│   ├── nvidia-gpu-operator/ # GPU operator overlay
│   └── team-queues/         # Team queue management
└── infrastructure/          # Base component definitions
    ├── kueue/               # Kueue base configuration
    └── nvidia-gpu-operator/ # GPU operator base configuration
```

## Key Features

- **GitOps Automation**: Changes to `./clusters/local` are automatically synchronized to the cluster
- **Resource Management**: CPU and GPU resource flavors with team-based queue isolation
- **Job Scheduling**: Kueue-based job queueing with support for batch workloads
- **GPU Support**: NVIDIA GPU Operator for containerized GPU workloads

## Getting Started

1. **Bootstrap Flux CD** in your cluster:
   ```bash
   GITHUB_TOKEN="<token>" flux bootstrap github \
     --owner="seemethere" \
     --repository="k8splay" \
     --branch=main \
     --path=./clusters/local \
     --personal
   ```

2. **Make changes** to infrastructure or cluster configurations
3. **Flux automatically syncs** changes within 1-10 minutes

## Documentation

See [CLAUDE.md](./CLAUDE.md) for detailed architecture, components, and development guidelines.