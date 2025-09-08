#!/bin/bash

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEAMS_DIR="$SCRIPT_DIR/local-queues"

# Get team name from argument or show usage
TEAM_NAME=${1:-}
if [ -z "$TEAM_NAME" ]; then
    echo "Usage: $0 <team-name>"
    echo
    echo "Available teams:"
    ls "$TEAMS_DIR" 2>/dev/null || echo "  No teams found"
    exit 1
fi

# Check if team directory exists
TEAM_DIR="$TEAMS_DIR/$TEAM_NAME"
if [ ! -d "$TEAM_DIR" ]; then
    echo "❌ Team '$TEAM_NAME' not found in local-queues directory"
    echo "Available teams:"
    ls "$TEAMS_DIR" 2>/dev/null || echo "  No teams found"
    exit 1
fi

echo "🧪 Validating Kueue Setup for Team: $TEAM_NAME"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check function
check() {
    if eval "$1"; then
        echo -e "${GREEN}✅ $2${NC}"
        return 0
    else
        echo -e "${RED}❌ $2${NC}"
        return 1
    fi
}

echo "1. Checking ResourceFlavors..."
check "kubectl get resourceflavors cpu-flavor &>/dev/null" "cpu-flavor exists"
check "kubectl get resourceflavors gpu-flavor &>/dev/null" "gpu-flavor exists"
echo

echo "2. Checking ClusterQueue for $TEAM_NAME..."
check "kubectl get clusterqueues ${TEAM_NAME}-cluster-queue &>/dev/null" "${TEAM_NAME}-cluster-queue exists"
echo

echo "3. Checking Namespace for $TEAM_NAME..."
check "kubectl get namespace $TEAM_NAME &>/dev/null" "$TEAM_NAME namespace exists"
echo

echo "4. Checking LocalQueues for $TEAM_NAME..."
# Find all local queues for this team
QUEUE_COUNT=$(kubectl get localqueues -n $TEAM_NAME --no-headers 2>/dev/null | wc -l)
if [ "$QUEUE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $QUEUE_COUNT local queue(s) for $TEAM_NAME:${NC}"
    kubectl get localqueues -n $TEAM_NAME --no-headers 2>/dev/null | awk '{print "  • " $1}'
else
    echo -e "${RED}❌ No local queues found for $TEAM_NAME${NC}"
fi
echo

echo "5. Testing Job Submission..."
# Use the first available local queue for testing
FIRST_QUEUE=$(kubectl get localqueues -n $TEAM_NAME --no-headers 2>/dev/null | head -1 | awk '{print $1}')
if [ -z "$FIRST_QUEUE" ]; then
    echo -e "${RED}❌ No queues available for testing${NC}"
    exit 1
fi

echo "Using queue: $FIRST_QUEUE"

kubectl apply -f - <<EOF &>/dev/null
apiVersion: batch/v1
kind: Job
metadata:
  name: validate-${TEAM_NAME}-queue
  namespace: $TEAM_NAME
  labels:
    kueue.x-k8s.io/queue-name: $FIRST_QUEUE
spec:
  template:
    spec:
      containers:
      - name: test
        image: busybox
        command: ["sh", "-c", "echo 'Validation successful for team $TEAM_NAME!'; sleep 2"]
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
      restartPolicy: Never
EOF

# Wait for job to complete with timeout
echo "Waiting for job to complete..."
TIMEOUT=60  # 60 seconds timeout
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    JOB_STATUS=$(kubectl get job validate-${TEAM_NAME}-queue -n $TEAM_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || echo "")
    if [ "$JOB_STATUS" = "True" ]; then
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    echo -n "."
done
echo

if [ "$JOB_STATUS" = "True" ]; then
    echo -e "${GREEN}✅ Job completed successfully in $FIRST_QUEUE${NC}"
else
    echo -e "${RED}❌ Job did not complete within ${TIMEOUT}s timeout${NC}"
fi

# Get job logs
echo -e "${YELLOW}📄 Job output:${NC}"
kubectl logs job/validate-${TEAM_NAME}-queue -n $TEAM_NAME 2>/dev/null || echo "  (logs not available yet)"
echo

echo "6. Checking Workload Management..."
check "kubectl get workloads -n $TEAM_NAME --no-headers 2>/dev/null | wc -l | grep -q '[1-9]'" "Workloads are being managed"
echo

# Cleanup
echo "🧹 Cleaning up test resources..."
kubectl delete job validate-${TEAM_NAME}-queue -n $TEAM_NAME &>/dev/null || true

echo -e "${GREEN}🎉 Queue validation completed successfully for team: $TEAM_NAME!${NC}"
echo
echo "Available queues for $TEAM_NAME:"
kubectl get localqueues -n $TEAM_NAME --no-headers 2>/dev/null | awk '{print "  • " $1 " (ClusterQueue: " $2 ")"}'