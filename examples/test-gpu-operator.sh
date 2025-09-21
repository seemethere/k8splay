#!/bin/bash

# GPU Operator Test Script
# This script helps test the NVIDIA GPU Operator deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 NVIDIA GPU Operator Test Script${NC}"
echo "=========================================="

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}❌ kubectl is not available. Please install kubectl first.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ kubectl found${NC}"
}

# Function to check if we can connect to cluster
check_cluster_connection() {
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}❌ Cannot connect to Kubernetes cluster. Please check your kubeconfig.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Connected to Kubernetes cluster${NC}"
    kubectl cluster-info | head -1
}

# Function to check GPU operator pods
check_gpu_operator_status() {
    echo -e "\n${YELLOW}📋 Checking GPU Operator Pod Status...${NC}"
    
    # Check if nvidia-gpu-operator namespace exists
    if ! kubectl get namespace nvidia-gpu-operator &> /dev/null; then
        echo -e "${RED}❌ nvidia-gpu-operator namespace not found${NC}"
        echo "   The GPU operator may not be deployed yet."
        return 1
    fi
    
    echo "GPU Operator Pods:"
    kubectl get pods -n nvidia-gpu-operator -o wide
    
    # Check for any failing pods
    failing_pods=$(kubectl get pods -n nvidia-gpu-operator --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
    if [ "$failing_pods" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Some GPU operator pods are not running${NC}"
        kubectl get pods -n nvidia-gpu-operator --field-selector=status.phase!=Running
    else
        echo -e "${GREEN}✅ All GPU operator pods are running${NC}"
    fi
}

# Function to check for GPU nodes
check_gpu_nodes() {
    echo -e "\n${YELLOW}🖥️  Checking for GPU Nodes...${NC}"
    
    gpu_nodes=$(kubectl get nodes -l nvidia.com/gpu.present=true --no-headers 2>/dev/null | wc -l)
    if [ "$gpu_nodes" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  No nodes with nvidia.com/gpu.present=true label found${NC}"
        echo "   This could mean:"
        echo "   1. No GPU hardware available"
        echo "   2. GPU operator hasn't labeled nodes yet"
        echo "   3. Nodes are still being configured"
    else
        echo -e "${GREEN}✅ Found $gpu_nodes GPU node(s)${NC}"
        kubectl get nodes -l nvidia.com/gpu.present=true -o custom-columns="NAME:.metadata.name,GPU-TYPE:.metadata.labels.nvidia\.com/gpu\.product,DRIVER:.metadata.labels.nvidia\.com/cuda\.driver\.major"
    fi
}

# Function to run basic GPU test
run_basic_test() {
    echo -e "\n${YELLOW}🧪 Running Basic GPU Test...${NC}"
    
    # Clean up any existing test job
    kubectl delete job gpu-driver-test --ignore-not-found=true
    
    # Apply the test job
    kubectl apply -f "$SCRIPT_DIR/gpu-test-job.yaml"
    
    echo "Waiting for job to complete..."
    kubectl wait --for=condition=complete --timeout=300s job/gpu-driver-test
    
    echo -e "\n${GREEN}📊 Test Results:${NC}"
    kubectl logs job/gpu-driver-test
    
    # Clean up
    echo -e "\n${YELLOW}🧹 Cleaning up test job...${NC}"
    kubectl delete job gpu-driver-test
}

# Function to run Kueue GPU test
run_kueue_test() {
    echo -e "\n${YELLOW}🎯 Running Kueue GPU Test...${NC}"
    
    # Check if core-team namespace exists
    if ! kubectl get namespace core-team &> /dev/null; then
        echo -e "${YELLOW}⚠️  core-team namespace not found. Creating it...${NC}"
        kubectl create namespace core-team
    fi
    
    # Clean up any existing test job
    kubectl delete job gpu-driver-test-kueue -n core-team --ignore-not-found=true
    
    # Apply the test job
    kubectl apply -f "$SCRIPT_DIR/gpu-test-job-kueue.yaml"
    
    echo "Waiting for job to be scheduled and complete..."
    kubectl wait --for=condition=complete --timeout=300s job/gpu-driver-test-kueue -n core-team
    
    echo -e "\n${GREEN}📊 Kueue Test Results:${NC}"
    kubectl logs job/gpu-driver-test-kueue -n core-team
    
    # Show Kueue workload status
    echo -e "\n${YELLOW}📋 Kueue Workload Status:${NC}"
    kubectl get workloads -n core-team 2>/dev/null || echo "No workloads found or Kueue CRDs not installed"
    
    # Clean up
    echo -e "\n${YELLOW}🧹 Cleaning up test job...${NC}"
    kubectl delete job gpu-driver-test-kueue -n core-team
}

# Main menu
show_menu() {
    echo -e "\n${YELLOW}Choose a test to run:${NC}"
    echo "1) Quick status check (pods, nodes, resources)"
    echo "2) Basic GPU test (no Kueue)"
    echo "3) Kueue GPU test (with queue scheduling)"
    echo "4) Full test suite (all of the above)"
    echo "5) Exit"
    echo
    read -p "Enter your choice (1-5): " choice
}

# Main execution
main() {
    check_kubectl
    check_cluster_connection
    
    while true; do
        show_menu
        case $choice in
            1)
                check_gpu_operator_status
                check_gpu_nodes
                ;;
            2)
                check_gpu_operator_status
                check_gpu_nodes
                run_basic_test
                ;;
            3)
                check_gpu_operator_status
                check_gpu_nodes
                run_kueue_test
                ;;
            4)
                check_gpu_operator_status
                check_gpu_nodes
                run_basic_test
                echo -e "\n${YELLOW}===============================================${NC}"
                run_kueue_test
                ;;
            5)
                echo -e "${GREEN}👋 Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid choice. Please enter 1-5.${NC}"
                ;;
        esac
        echo -e "\n${YELLOW}Press Enter to continue...${NC}"
        read
    done
}

# Run main function
main
