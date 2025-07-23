#!/bin/bash

# Cleanup Duplicate Deployments Script
NAMESPACE="egov"

echo "=== Cleaning up duplicate deployments in $NAMESPACE namespace ==="

# Function to safely delete older deployment
cleanup_service() {
    local service_name=$1
    echo "Processing $service_name..."
    
    # Get all deployments for this service
    deployments=$(kubectl get deployments -n $NAMESPACE | grep "^$service_name-" | awk '{print $1}')
    
    if [ $(echo "$deployments" | wc -l) -gt 1 ]; then
        echo "Found multiple deployments for $service_name:"
        echo "$deployments"
        
        # Get the newest deployment (assuming higher hash = newer)
        newest=$(echo "$deployments" | tail -1)
        
        # Delete older deployments
        for deployment in $deployments; do
            if [ "$deployment" != "$newest" ]; then
                echo "Deleting older deployment: $deployment"
                kubectl delete deployment $deployment -n $NAMESPACE
            fi
        done
    else
        echo "Only one deployment found for $service_name, skipping..."
    fi
    echo ""
}

# List of services with duplicates
services=(
    "audit-service"
    "egov-accesscontrol"
    "egov-enc-service"
    "egov-filestore"
    "egov-hrms"
    "egov-idgen"
    "egov-indexer"
    "egov-localization"
    "egov-location"
    "egov-otp"
    "egov-persister"
    "egov-pg-service"
    "egov-url-shortening"
    "egov-user"
    "egov-user-event"
    "egov-workflow-v2"
    "pgr-services"
    "service-request"
    "user-otp"
)

# Clean up each service
for service in "${services[@]}"; do
    cleanup_service $service
done

echo "=== Cleanup completed ==="
echo "Waiting for pods to stabilize..."
sleep 30

echo "=== Current pod status ==="
kubectl get pods -n $NAMESPACE