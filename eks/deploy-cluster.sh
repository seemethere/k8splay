#!/bin/bash

# EKS Cluster Deployment Script
# This script deploys the k8splay EKS cluster with proper environment variable substitution

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if required tools are installed
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v eksctl &> /dev/null; then
        print_error "eksctl is not installed. Please install it from https://eksctl.io/installation/"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v envsubst &> /dev/null; then
        print_error "envsubst is not installed. Please install gettext package."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Check AWS credentials
check_aws_credentials() {
    print_info "Checking AWS credentials..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local user_arn=$(aws sts get-caller-identity --query Arn --output text)
    
    print_success "AWS credentials are configured"
    print_info "Account ID: $account_id"
    print_info "User ARN: $user_arn"
}

# Set environment variables
set_environment_variables() {
    export USER=${USER:-$(whoami)}
    export REGION=${REGION:-us-west-2}
    
    print_info "Environment variables set:"
    print_info "USER: $USER"
    print_info "REGION: $REGION"
    print_info "Cluster name will be: ${USER}-${REGION}-k8splay-cluster"
}

# Deploy the cluster
deploy_cluster() {
    print_info "Starting cluster deployment..."
    
    # Get the directory where this script is located
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local config_file="$script_dir/cluster.yaml"
    local resolved_config="$script_dir/cluster-resolved.yaml"
    
    if [ ! -f "$config_file" ]; then
        print_error "cluster.yaml not found in script directory: $script_dir"
        exit 1
    fi
    
    # Substitute environment variables
    print_info "Resolving environment variables in configuration..."
    envsubst < "$config_file" > "$resolved_config"
    
    print_info "Configuration resolved. Starting cluster creation..."
    print_warning "This will take approximately 15-20 minutes..."
    
    if eksctl create cluster -f "$resolved_config"; then
        print_success "Cluster created successfully!"
        
        # Clean up resolved config file
        rm -f "$resolved_config"
        
        # Update kubeconfig
        print_info "Updating kubeconfig..."
        eksctl utils write-kubeconfig --cluster "${USER}-${REGION}-k8splay-cluster" --region "$REGION"
        
        # Verify cluster
        print_info "Verifying cluster..."
        kubectl get nodes
        
        print_success "Deployment completed successfully!"
        print_info "Your cluster '${USER}-${REGION}-k8splay-cluster' is ready to use."
        
        # Show next steps
        echo
        print_info "Next steps:"
        echo "1. Install NVIDIA GPU Operator: kubectl apply -k ../clusters/local/nvidia-gpu-operator/"
        echo "2. Install Kueue: kubectl apply -k ../clusters/local/kueue/"
        echo "3. Apply team queues: kubectl apply -k ../clusters/local/team-queues/"
        echo "4. Install monitoring: kubectl apply -k ../clusters/local/prometheus/"
        
    else
        print_error "Cluster creation failed"
        rm -f "$resolved_config"
        exit 1
    fi
}

# Main function
main() {
    print_info "🚀 Starting EKS cluster deployment for k8splay"
    echo
    
    check_prerequisites
    check_aws_credentials
    set_environment_variables
    
    echo
    print_warning "About to create EKS cluster with the following configuration:"
    echo "  - Name: ${USER}-${REGION}-k8splay-cluster"
    echo "  - Region: $REGION"
    echo "  - CPU Nodes: c5.4xlarge (2 nodes, max 4)"
    echo "  - GPU Nodes: g4dn.12xlarge (0 node, max 4)"
    echo "  - Estimated cost: ~\$1-3/hour (depending on usage)"
    echo
    
    read -p "Do you want to proceed? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deployment cancelled by user"
        exit 0
    fi
    
    deploy_cluster
}

# Run main function
main "$@"
