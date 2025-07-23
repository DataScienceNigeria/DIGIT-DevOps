#!/bin/bash

echo "=== Locating Common Template Issue ==="

cd /home/ubuntu/DPI/DIGIT-DevOps/deploy-as-code/charts

echo "Current directory: $(pwd)"

echo -e "\n=== 1. Finding Common Chart ==="
# Look for the common chart referenced in dependencies
find . -name "common" -type d

echo -e "\n=== 2. Examining Common Chart Structure ==="
if [ -d "common" ]; then
    echo "Common chart found at: ./common"
    echo "Common chart structure:"
    find common -type f | head -20
    
    echo -e "\n=== 3. Looking for Deployment Template in Common ==="
    if [ -f "common/templates/deployment.yaml" ]; then
        echo "Found common deployment template:"
        echo "--- START OF COMMON DEPLOYMENT TEMPLATE ---"
        cat common/templates/deployment.yaml
        echo "--- END OF COMMON DEPLOYMENT TEMPLATE ---"
    else
        echo "No deployment.yaml in common/templates. Checking for other template files:"
        find common/templates -name "*.yaml" -o -name "*.tpl" 2>/dev/null
        
        # Check for _deployment.tpl or similar
        if [ -f "common/templates/_deployment.tpl" ]; then
            echo -e "\nFound _deployment.tpl:"
            cat common/templates/_deployment.tpl
        fi
        
        # Check for helpers
        if [ -f "common/templates/_helpers.tpl" ]; then
            echo -e "\nChecking _helpers.tpl for deployment definition:"
            grep -A 50 -B 5 "define.*deployment\|deployment.*define" common/templates/_helpers.tpl || echo "No deployment definition found in helpers"
        fi
    fi
    
    echo -e "\n=== 4. Searching for ServiceAccount References in Common Templates ==="
    find common -name "*.yaml" -o -name "*.tpl" | xargs grep -n "serviceAccount" 2>/dev/null || echo "No serviceAccount references found"
    
else
    echo "Common chart not found in current directory. Checking other locations..."
    
    # Check if common is in a different location
    find . -name "Chart.yaml" -exec grep -l "name: common" {} \; 2>/dev/null
    
    # Check for common in parent directories
    find .. -name "common" -type d 2>/dev/null | head -5
fi

echo -e "\n=== 5. Checking Gateway Chart Dependencies ==="
if [ -f "core-services/gateway/Chart.yaml" ]; then
    echo "Gateway Chart.yaml dependencies:"
    grep -A 10 "dependencies:" core-services/gateway/Chart.yaml
    
    echo -e "\nChecking if common chart is downloaded:"
    if [ -d "core-services/gateway/charts" ]; then
        echo "Downloaded dependencies:"
        ls -la core-services/gateway/charts/
        
        if [ -d "core-services/gateway/charts/common" ]; then
            echo -e "\nCommon chart templates in downloaded dependency:"
            find core-services/gateway/charts/common -name "*.yaml" -o -name "*.tpl" | head -10
            
            echo -e "\nChecking for deployment template in downloaded common chart:"
            if [ -f "core-services/gateway/charts/common/templates/_helpers.tpl" ]; then
                echo "Searching for deployment definition in common helpers:"
                grep -A 100 "define.*deployment" core-services/gateway/charts/common/templates/_helpers.tpl | head -50
            fi
        fi
    fi
fi

echo -e "\n=== 6. Alternative: Check if Common is in Different Location ==="
# Sometimes common charts are in a different structure
find . -path "*/common/templates/*" -name "*deployment*" 2>/dev/null

echo -e "\n=== 7. Summary and Next Steps ==="
echo "The issue is in the common deployment template that's being used by:"
echo "{{- template \"common.deployment\" . -}}"
echo ""
echo "We need to find and fix the serviceAccount reference in the common template."
echo "Look for a line like:"
echo "  serviceAccountName: {{ .Values.serviceAccount }}"
echo "And change it to:"
echo "  serviceAccountName: {{ .Values.serviceAccount.name }}"