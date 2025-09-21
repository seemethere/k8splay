#!/bin/bash

# Install Cluster Autoscaler for EKS
# This script helps install the cluster autoscaler on your EKS cluster

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Installing Cluster Autoscaler for EKS${NC}"
echo "============================================"
echo ""
echo -e "${YELLOW}💡 Tip: Run ./scripts/test-cluster-detection.sh first to verify cluster detection${NC}"
echo ""

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

# Function to get cluster info via eksctl (fallback)
get_cluster_info_eksctl() {
    local cluster_name=""
    local region=""
    
    # Try to get cluster info from eksctl
    if command -v eksctl &> /dev/null; then
        local eksctl_output=$(eksctl get cluster -o json 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$eksctl_output" ]; then
            cluster_name=$(echo "$eksctl_output" | jq -r '.[0].Name // empty' 2>/dev/null)
            region=$(echo "$eksctl_output" | jq -r '.[0].Region // empty' 2>/dev/null)
        fi
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

# Detect current cluster and region
echo -e "${YELLOW}Current kubectl context: $(kubectl config current-context)${NC}"
echo -e "${YELLOW}🔍 Auto-detecting cluster information...${NC}"

# Try multiple methods to detect cluster info
CLUSTER_INFO=$(detect_cluster_info)
CLUSTER_NAME=$(echo "$CLUSTER_INFO" | cut -d: -f1)
AWS_REGION=$(echo "$CLUSTER_INFO" | cut -d: -f2)

# Fallback to eksctl if kubectl parsing failed
if [ -z "$CLUSTER_NAME" ] || [ -z "$AWS_REGION" ]; then
    echo -e "${YELLOW}Trying eksctl for cluster detection...${NC}"
    EKSCTL_INFO=$(get_cluster_info_eksctl)
    if [ -n "$(echo "$EKSCTL_INFO" | cut -d: -f1)" ]; then
        CLUSTER_NAME=$(echo "$EKSCTL_INFO" | cut -d: -f1)
        AWS_REGION=$(echo "$EKSCTL_INFO" | cut -d: -f2)
    fi
fi

# Fallback to region detection from cluster endpoint
if [ -z "$AWS_REGION" ]; then
    echo -e "${YELLOW}Trying cluster endpoint for region detection...${NC}"
    AWS_REGION=$(get_region_from_cluster)
fi

# Final fallback to AWS CLI configured region
if [ -z "$AWS_REGION" ]; then
    AWS_REGION=$(aws configure get region 2>/dev/null || echo "us-west-2")
    echo -e "${YELLOW}⚠️  Using AWS CLI configured region as fallback${NC}"
fi

# Prompt for missing information
if [ -z "$CLUSTER_NAME" ]; then
    echo -e "${YELLOW}⚠️  Could not auto-detect cluster name${NC}"
    echo "Please enter your EKS cluster name:"
    read -p "Cluster name: " CLUSTER_NAME
fi

if [ -z "$AWS_REGION" ]; then
    echo -e "${YELLOW}⚠️  Could not auto-detect region${NC}"
    echo "Please enter your AWS region (e.g., us-west-2):"
    read -p "Region: " AWS_REGION
fi

echo -e "${YELLOW}📋 Configuration:${NC}"
echo "  - Cluster: $CLUSTER_NAME"
echo "  - Region: $AWS_REGION"
echo ""

# Confirm with user
read -p "Is this correct? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Please run the script again with the correct information${NC}"
    exit 0
fi

# Check if cluster autoscaler service account exists
echo -e "${YELLOW}🔍 Checking for existing service account...${NC}"
if kubectl get serviceaccount cluster-autoscaler -n kube-system &>/dev/null; then
    echo -e "${GREEN}✅ Found existing cluster-autoscaler service account${NC}"
else
    echo -e "${RED}❌ cluster-autoscaler service account not found${NC}"
    echo "This should have been created by eksctl. Please check your cluster configuration."
    exit 1
fi

# Create temporary directory for manifests
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Create the helm release with actual cluster name
echo -e "${YELLOW}📝 Creating cluster autoscaler configuration...${NC}"
cat > "$TEMP_DIR/cluster-autoscaler-release.yaml" << EOF
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: cluster-autoscaler
  namespace: cluster-autoscaler
spec:
  interval: 10m
  chart:
    spec:
      chart: cluster-autoscaler
      version: ">=1.0.0"
      sourceRef:
        kind: HelmRepository
        name: autoscaler
        namespace: cluster-autoscaler
  # Install to kube-system namespace to use existing service account
  targetNamespace: kube-system
  values:
    # Use existing service account created by eksctl
    rbac:
      serviceAccount:
        create: false
        name: cluster-autoscaler
    
    # Auto-discovery configuration for EKS
    autoDiscovery:
      clusterName: "$CLUSTER_NAME"
      enabled: true
      tags:
        - k8s.io/cluster-autoscaler/enabled
        - k8s.io/cluster-autoscaler/$CLUSTER_NAME
    
    # AWS region
    awsRegion: $AWS_REGION
    
    # Image configuration  
    image:
      repository: registry.k8s.io/autoscaling/cluster-autoscaler
      tag: v1.30.0  # Match your EKS version
    
    # Resource configuration
    resources:
      limits:
        cpu: 100m
        memory: 600Mi
      requests:
        cpu: 100m
        memory: 600Mi
    
    # Pod configuration
    nodeSelector:
      node-type: cpu  # Schedule on CPU nodes only
    
    # Autoscaler configuration
    extraArgs:
      v: 4
      stderrthreshold: info
      cloud-provider: aws
      skip-nodes-with-local-storage: false
      expander: least-waste
      node-group-auto-discovery: asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/$CLUSTER_NAME
      balance-similar-node-groups: false
      skip-nodes-with-system-pods: false
EOF

echo -e "${YELLOW}🛠️  Installing cluster autoscaler components...${NC}"

# Install using existing infrastructure
if [ -d "infrastructure/cluster-autoscaler" ]; then
    echo "Installing via Flux/GitOps..."
    
    # Update the placeholders in the helm release
    sed -e "s/CLUSTER_NAME_PLACEHOLDER/$CLUSTER_NAME/g" \
        -e "s/AWS_REGION_PLACEHOLDER/$AWS_REGION/g" \
        infrastructure/cluster-autoscaler/helm-release.yaml > "$TEMP_DIR/updated-helm-release.yaml"
    cp "$TEMP_DIR/updated-helm-release.yaml" infrastructure/cluster-autoscaler/helm-release.yaml
    
    kubectl apply -k infrastructure/cluster-autoscaler/
else
    echo "Installing directly via kubectl..."
    
    # Create namespace and helm repo
    kubectl create namespace cluster-autoscaler --dry-run=client -o yaml | kubectl apply -f -
    
    cat > "$TEMP_DIR/helm-repo.yaml" << EOF
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: autoscaler
  namespace: cluster-autoscaler
spec:
  interval: 1h
  url: https://kubernetes.github.io/autoscaler
EOF
    
    kubectl apply -f "$TEMP_DIR/helm-repo.yaml"
    kubectl apply -f "$TEMP_DIR/cluster-autoscaler-release.yaml"
fi

echo -e "${YELLOW}⏳ Waiting for cluster autoscaler to be ready...${NC}"
sleep 10

# Check deployment
echo -e "${YELLOW}🔍 Checking cluster autoscaler status...${NC}"
kubectl get pods -n kube-system -l app.kubernetes.io/name=cluster-autoscaler

echo ""
echo -e "${GREEN}✅ Cluster Autoscaler installation completed!${NC}"
echo ""
echo -e "${YELLOW}📋 Verification commands:${NC}"
echo "kubectl get pods -n kube-system -l app.kubernetes.io/name=cluster-autoscaler"
echo "kubectl logs -n kube-system -l app.kubernetes.io/name=cluster-autoscaler"
echo ""
echo -e "${GREEN}🎉 Your cluster should now auto-scale nodes based on pod demands!${NC}"
