#!/bin/bash

# Test script to verify cluster detection methods
# This helps debug cluster name and region detection

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔍 Testing EKS Cluster Detection Methods${NC}"
echo "========================================"

# Function to detect cluster name and region from kubectl context
detect_cluster_info() {
    local current_context=$(kubectl config current-context)
    local cluster_name=""
    local region=""
    
    # Parse eksctl context format: user@email@cluster-name.region.eksctl.io
    if [[ $current_context =~ .*@(.*)\.(.*)\.eksctl\.io ]]; then
        cluster_name="${BASH_REMATCH[1]}"
        region="${BASH_REMATCH[2]}"
    # Parse standard EKS context format if different
    elif [[ $current_context =~ .*@(.*)\.(.*)\.eks\.amazonaws\.com ]]; then
        cluster_name="${BASH_REMATCH[1]}"
        region="${BASH_REMATCH[2]}"
    fi
    
    echo "$cluster_name:$region"
}

# Function to get cluster info via eksctl
get_cluster_info_eksctl() {
    local cluster_name=""
    local region=""
    
    if command -v eksctl &> /dev/null; then
        local eksctl_output=$(eksctl get cluster -o json 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$eksctl_output" ]; then
            cluster_name=$(echo "$eksctl_output" | jq -r '.[0].Name // empty' 2>/dev/null)
            region=$(echo "$eksctl_output" | jq -r '.[0].Region // empty' 2>/dev/null)
        fi
    else
        echo "eksctl not found"
        return 1
    fi
    
    echo "$cluster_name:$region"
}

# Function to get region from cluster endpoint
get_region_from_cluster() {
    local cluster_endpoint
    cluster_endpoint=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)
    
    # Parse standard EKS endpoint format: https://xxx.gr7.region.eks.amazonaws.com
    if [[ $cluster_endpoint =~ https://.*\.gr[0-9]+\.(.*)\.eks\.amazonaws\.com ]]; then
        echo "${BASH_REMATCH[1]}"
    # Parse alternative format: https://xxx.region.eks.amazonaws.com
    elif [[ $cluster_endpoint =~ https://.*\.(.*)\.eks\.amazonaws\.com ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

echo -e "${YELLOW}Current kubectl context:${NC}"
kubectl config current-context

echo ""
echo -e "${YELLOW}Method 1 - kubectl context parsing:${NC}"
CLUSTER_INFO=$(detect_cluster_info)
CLUSTER_NAME=$(echo "$CLUSTER_INFO" | cut -d: -f1)
REGION=$(echo "$CLUSTER_INFO" | cut -d: -f2)
echo "  Cluster: $CLUSTER_NAME"
echo "  Region: $REGION"

echo ""
echo -e "${YELLOW}Method 2 - eksctl get cluster:${NC}"
EKSCTL_INFO=$(get_cluster_info_eksctl)
if [ $? -eq 0 ]; then
    EKSCTL_CLUSTER=$(echo "$EKSCTL_INFO" | cut -d: -f1)
    EKSCTL_REGION=$(echo "$EKSCTL_INFO" | cut -d: -f2)
    echo "  Cluster: $EKSCTL_CLUSTER"
    echo "  Region: $EKSCTL_REGION"
else
    echo "  Failed to get cluster info via eksctl"
fi

echo ""
echo -e "${YELLOW}Method 3 - cluster endpoint parsing:${NC}"
ENDPOINT_REGION=$(get_region_from_cluster)
echo "  Region: $ENDPOINT_REGION"

echo ""
echo -e "${YELLOW}Method 4 - AWS CLI configured region:${NC}"
CLI_REGION=$(aws configure get region 2>/dev/null || echo "not set")
echo "  Region: $CLI_REGION"

echo ""
echo -e "${YELLOW}Raw cluster server endpoint:${NC}"
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'

echo ""
echo ""
echo -e "${GREEN}✅ Detection test complete${NC}"
