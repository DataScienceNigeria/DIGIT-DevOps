#!/bin/bash

# Script to fix init container image references in DIGIT deployments
# This script adds the 'egovio/' prefix to init container images that are missing it

NAMESPACE="egov"

echo "Fixing init container image references in DIGIT deployments..."

# Get all deployments and check their init containers
deployments=$(kubectl get deployments -n $NAMESPACE -o name | sed 's/deployment.apps\///')

for deployment in $deployments; do
    echo "Checking deployment: $deployment"
    
    # Get the deployment spec
    deployment_spec=$(kubectl get deployment $deployment -n $NAMESPACE -o json)
    
    # Check if deployment has init containers
    init_containers=$(echo "$deployment_spec" | jq -r '.spec.template.spec.initContainers[]? | select(.image | startswith("egovio/") | not) | .name + ":" + .image')
    
    if [ ! -z "$init_containers" ]; then
        echo "  Found init containers needing fixes:"
        echo "$init_containers" | while read line; do
            if [ ! -z "$line" ]; then
                container_name=$(echo "$line" | cut -d: -f1)
                current_image=$(echo "$line" | cut -d: -f2-)
                new_image="egovio/$current_image"
                
                echo "    → Updating init container $container_name: $current_image -> $new_image"
                
                # Create a patch for the init container
                patch_json=$(cat <<EOF
{
  "spec": {
    "template": {
      "spec": {
        "initContainers": [
          {
            "name": "$container_name",
            "image": "$new_image"
          }
        ]
      }
    }
  }
}
EOF
)
                
                # Apply the patch using strategic merge
                kubectl patch deployment $deployment -n $NAMESPACE --type='strategic' -p "$patch_json"
                
                if [ $? -eq 0 ]; then
                    echo "    ✓ Successfully updated init container $container_name in $deployment"
                else
                    echo "    ✗ Failed to update init container $container_name in $deployment"
                fi
            fi
        done
    else
        echo "  ✓ No init container fixes needed for $deployment"
    fi
    
    echo ""
done

echo "Init container image reference fixes completed!"