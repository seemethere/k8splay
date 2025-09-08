#!/bin/bash

# Script to extract kubeconfig from existing GitOps-managed ServiceAccount
# Usage: ./generate-team-kubeconfig.sh <team-name>
# Namespace will be inferred as: <team-name> (e.g., core-team -> core-team)

set -e

TEAM_NAME=${1:-"core-team"}
NAMESPACE=${TEAM_NAME}
SERVICE_ACCOUNT="${TEAM_NAME}-kubeconfig-sa"
SECRET_NAME="${SERVICE_ACCOUNT}-token"
KUBECONFIG_FILE="${TEAM_NAME}-kubeconfig.yaml"

echo "Extracting kubeconfig for team: $TEAM_NAME in namespace: $NAMESPACE"

# Check if ServiceAccount exists (should be managed by GitOps)
if ! kubectl get serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE &>/dev/null; then
  echo "Error: ServiceAccount $SERVICE_ACCOUNT not found in namespace $NAMESPACE"
  echo "Make sure the GitOps manifests are deployed by Flux"
  exit 1
fi

# Wait for token to be available
echo "Waiting for token to be available..."
while ! kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.token}' &>/dev/null; do
  echo "Waiting for secret $SECRET_NAME to be created..."
  sleep 2
done

# Get cluster info
CLUSTER_NAME=$(kubectl config current-context)
CLUSTER_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# Get service account token and certificate
TOKEN=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.token}' | base64 --decode)
CERTIFICATE=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.ca\.crt}')

# Generate kubeconfig
cat <<EOF > $KUBECONFIG_FILE
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $CERTIFICATE
    server: $CLUSTER_SERVER
  name: $CLUSTER_NAME
contexts:
- context:
    cluster: $CLUSTER_NAME
    namespace: $NAMESPACE
    user: $SERVICE_ACCOUNT
  name: $TEAM_NAME-context
current-context: $TEAM_NAME-context
users:
- name: $SERVICE_ACCOUNT
  user:
    token: $TOKEN
EOF

echo "Kubeconfig generated: $KUBECONFIG_FILE"
echo ""
echo "To use this kubeconfig:"
echo "  export KUBECONFIG=$PWD/$KUBECONFIG_FILE"
echo "  kubectl get pods"
echo ""
echo "Create a job in the queue:"
echo "  kubectl create job test-job --image=busybox -- echo 'hello from $TEAM_NAME'"
echo "  kubectl patch job test-job --type=merge -p '{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"kueue.x-k8s.io/queue-name\":\"${TEAM_NAME}-general-queue\"}}}}}'"
