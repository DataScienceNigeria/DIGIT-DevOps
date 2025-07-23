#!/bin/bash

# Kubernetes Pod Debugging Script for DIGIT Platform
# This script helps diagnose common issues with failing pods

NAMESPACE="egov"
LOG_FILE="pod-debug-$(date +%Y%m%d-%H%M%S).log"

echo "=== DIGIT Platform Pod Debugging ===" | tee $LOG_FILE
echo "Timestamp: $(date)" | tee -a $LOG_FILE
echo "Namespace: $NAMESPACE" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# Function to check pod details
check_pod_details() {
    local pod_name=$1
    echo "=== Checking Pod: $pod_name ===" | tee -a $LOG_FILE
    
    # Get pod description
    echo "--- Pod Description ---" | tee -a $LOG_FILE
    kubectl describe pod $pod_name -n $NAMESPACE | tee -a $LOG_FILE
    
    # Get pod logs
    echo "--- Pod Logs ---" | tee -a $LOG_FILE
    kubectl logs $pod_name -n $NAMESPACE --all-containers=true --previous=false | tee -a $LOG_FILE
    
    # Get init container logs if they exist
    echo "--- Init Container Logs ---" | tee -a $LOG_FILE
    kubectl logs $pod_name -n $NAMESPACE -c git-sync 2>/dev/null | tee -a $LOG_FILE || echo "No git-sync init container found" | tee -a $LOG_FILE
    
    echo "" | tee -a $LOG_FILE
}

# Get all failing pods
echo "=== Identifying Failing Pods ===" | tee -a $LOG_FILE
FAILING_PODS=$(kubectl get pods -n $NAMESPACE --no-headers | grep -E "(ImagePullBackOff|CrashLoopBackOff|Init:)" | awk '{print $1}')

if [ -z "$FAILING_PODS" ]; then
    echo "No failing pods found!" | tee -a $LOG_FILE
    exit 0
fi

echo "Found failing pods:" | tee -a $LOG_FILE
echo "$FAILING_PODS" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# Check each failing pod
for pod in $FAILING_PODS; do
    check_pod_details $pod
done

# Check for common issues
echo "=== Common Issue Analysis ===" | tee -a $LOG_FILE

# Check if git-sync init containers can access repositories
echo "--- Git Repository Access Check ---" | tee -a $LOG_FILE
echo "Testing git repository access..." | tee -a $LOG_FILE

# Test egov-mdms-data repository
echo "Testing egov-mdms-data repository:" | tee -a $LOG_FILE
curl -s -o /dev/null -w "%{http_code}" https://github.com/egovernments/egov-mdms-data | tee -a $LOG_FILE

# Test configs repository
echo "Testing configs repository:" | tee -a $LOG_FILE
curl -s -o /dev/null -w "%{http_code}" https://github.com/egovernments/configs | tee -a $LOG_FILE

# Check network connectivity
echo "--- Network Connectivity Check ---" | tee -a $LOG_FILE
echo "Checking DNS resolution..." | tee -a $LOG_FILE
nslookup github.com | tee -a $LOG_FILE

# Check for duplicate deployments
echo "--- Duplicate Deployment Check ---" | tee -a $LOG_FILE
echo "Checking for duplicate deployments..." | tee -a $LOG_FILE
kubectl get deployments -n $NAMESPACE | grep -E "(egov-|audit-|pgr-)" | tee -a $LOG_FILE

# Provide recommendations
echo "=== Recommendations ===" | tee -a $LOG_FILE
echo "1. Clean up duplicate deployments" | tee -a $LOG_FILE
echo "2. Check git repository access and credentials" | tee -a $LOG_FILE
echo "3. Verify init container image availability" | tee -a $LOG_FILE
echo "4. Check resource limits and node capacity" | tee -a $LOG_FILE
echo "5. Verify database connectivity" | tee -a $LOG_FILE

echo "" | tee -a $LOG_FILE
echo "Debug log saved to: $LOG_FILE" | tee -a $LOG_FILE
