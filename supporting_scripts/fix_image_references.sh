#!/bin/bash

# Script to fix image references in DIGIT deployments
# This script adds the 'egovio/' prefix to images that are missing it

NAMESPACE="egov"

# List of deployments that need fixing (without egovio/ prefix)
DEPLOYMENTS=(
    "audit-service"
    "citizen"
    "digit-ui"
    "egov-accesscontrol"
    "egov-enc-service"
    "egov-filestore"
    "egov-hrms"
    "egov-idgen"
    "egov-indexer"
    "egov-localization"
    "egov-location"
    "egov-mdms-service"
    "egov-notification-mail"
    "egov-notification-sms"
    "egov-otp"
    "egov-persister"
    "egov-pg-service"
    "egov-url-shortening"
    "egov-user"
    "egov-user-event"
    "egov-workflow-v2"
    "employee"
    "pgr-services"
    "service-request"
    "user-otp"
)

echo "Fixing image references in DIGIT deployments..."

for deployment in "${DEPLOYMENTS[@]}"; do
    echo "Processing deployment: $deployment"
    
    # Get current image
    current_image=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
    
    if [ $? -eq 0 ] && [ ! -z "$current_image" ]; then
        # Check if image already has egovio/ prefix
        if [[ $current_image == egovio/* ]]; then
            echo "  ✓ $deployment already has correct image reference: $current_image"
        else
            # Add egovio/ prefix
            new_image="egovio/$current_image"
            echo "  → Updating $deployment: $current_image -> $new_image"
            
            # Update the deployment
            kubectl patch deployment $deployment -n $NAMESPACE -p "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"$deployment\",\"image\":\"$new_image\"}]}}}}"
            
            if [ $? -eq 0 ]; then
                echo "  ✓ Successfully updated $deployment"
            else
                echo "  ✗ Failed to update $deployment"
            fi
        fi
    else
        echo "  ⚠ Deployment $deployment not found or error getting image"
    fi
    
    echo ""
done

echo "Image reference fixes completed!"
echo ""
echo "Checking for init container images that might also need fixing..."

# Check for init containers that might need fixing
kubectl get pods -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.initContainers[*]}{.image}{"\n"}{end}{end}' | grep -v "egovio/" | head -10

echo ""
echo "You may also need to fix init container images. Check the pod specifications for any init containers with missing egovio/ prefixes."