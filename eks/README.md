# EKS Cluster Configuration

This directory contains the EKS cluster configuration for the k8splay Kubernetes playground.

## 📋 Configuration Overview

The `cluster.yaml` file defines an EKS cluster with the following specifications:

### Cluster Details
- **Name**: `${USER}-${REGION}-k8splay-cluster` (e.g., `eliuriegas-us-west-2-k8splay-cluster`)
- **Region**: `us-west-2`
- **Kubernetes Version**: `1.28`
- **VPC**: New VPC with CIDR `10.0.0.0/16`

### Node Groups

#### 🖥️ CPU Workers (`cpu-workers`)
- **Instance Type**: `c7a.4xlarge` (16 vCPUs, 32 GiB RAM)
- **Capacity**: 2 nodes (default), 1-4 nodes (min-max)
- **Storage**: 100 GiB GP3 EBS
- **Labels**: `node-type=cpu`, `workload-type=general`

#### 🎮 GPU Workers (`gpu-workers`)
- **Instance Type**: `g4dn.12xlarge` (48 vCPUs, 192 GiB RAM, 4x NVIDIA T4 GPUs)
- **Capacity**: 1 node (default), 0-4 nodes (min-max)
- **Storage**: 200 GiB GP3 EBS
- **Labels**: `node-type=gpu`, `workload-type=ml-ai`, `nvidia.com/gpu=true`
- **Taints**: `nvidia.com/gpu=true:NoSchedule`

### 🔧 Enabled Add-ons & Features

- **VPC CNI** with Pod ENI and Prefix Delegation
- **CoreDNS** for cluster DNS
- **Kube-proxy** for network proxying
- **AWS EBS CSI Driver** for persistent volumes
- **AWS EFS CSI Driver** for shared file systems
- **Cluster Autoscaler** (via service account)
- **CloudWatch Logging** (30-day retention)

## 🚀 Deployment

### Prerequisites

1. **AWS CLI** configured with appropriate permissions
2. **eksctl** installed ([Installation Guide](https://eksctl.io/installation/))
3. **kubectl** installed
4. Appropriate IAM permissions for EKS cluster creation

### Deploy the Cluster

```bash
# Set environment variables
export USER=$(whoami)
export REGION=us-west-2

# Substitute variables in the config
envsubst < cluster.yaml > cluster-resolved.yaml

# Create the cluster
eksctl create cluster -f cluster-resolved.yaml
```

### Alternative: One-liner deployment

```bash
USER=$(whoami) REGION=us-west-2 envsubst < cluster.yaml | eksctl create cluster -f -
```

## 🎯 Post-Deployment Setup

After the cluster is created, you'll want to install additional components that align with your k8splay setup:

### 1. GPU Support
```bash
# Install NVIDIA GPU Operator (if not using your existing Flux setup)
kubectl apply -k ../clusters/local/nvidia-gpu-operator/
```

### 2. Kueue Job Scheduling
```bash
# Install Kueue (if not using your existing Flux setup)
kubectl apply -k ../clusters/local/kueue/
```

### 3. Team Queues
```bash
# Apply team-based resource management
kubectl apply -k ../clusters/local/team-queues/
```

### 4. Monitoring
```bash
# Install Prometheus monitoring
kubectl apply -k ../clusters/local/prometheus/
```

## 🔍 Verification

```bash
# Check cluster status
eksctl get cluster --region us-west-2

# Check nodes
kubectl get nodes -L node-type,workload-type

# Check GPU nodes specifically
kubectl get nodes -l nvidia.com/gpu=true

# Check installed add-ons
eksctl get addon --cluster ${USER}-${REGION}-k8splay-cluster --region us-west-2
```

## 🧹 Cleanup

```bash
# Delete the cluster
eksctl delete cluster -f cluster-resolved.yaml --wait

# Or by name
eksctl delete cluster --name ${USER}-${REGION}-k8splay-cluster --region us-west-2 --wait
```

## 🏗️ Architecture Notes

This cluster is designed to integrate with your existing k8splay infrastructure:

- **GitOps Ready**: Compatible with your Flux setup
- **Multi-tenancy**: Supports team-based resource isolation via Kueue
- **Hybrid Workloads**: Separate node groups for CPU and GPU workloads
- **Observability**: CloudWatch logging and Prometheus-ready
- **Auto-scaling**: Both cluster and pod auto-scaling enabled

## 💡 Tips

1. **Cost Optimization**: GPU nodes start at 0 and scale up as needed
2. **Resource Management**: Use your existing Kueue setup for job scheduling
3. **Monitoring**: Leverage your Prometheus setup for cluster monitoring
4. **GitOps**: Consider managing this cluster config through Flux as well

## 🔗 Related Documentation

- [eksctl Documentation](https://eksctl.io/)
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
