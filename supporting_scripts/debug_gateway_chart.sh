#!/bin/bash

echo "=== Debugging Gateway Chart and Helmfile Configuration ==="

# Navigate to the correct directory
cd deploy-as-code/charts/core-services

echo "Current directory: $(pwd)"

echo -e "\n=== 1. Examining Helmfile Configuration ==="
if [ -f "coreservices-helmfile.yaml.gotmpl" ]; then
    echo "Gateway configuration in helmfile:"
    awk '/- name: gateway/,/^- name:/ {if (/^- name:/ && !/- name: gateway/) exit; print}' coreservices-helmfile.yaml.gotmpl
    
    echo -e "\n=== Looking for default configuration ==="
    grep -A 30 "default:" coreservices-helmfile.yaml.gotmpl | head -40
fi

echo -e "\n=== 2. Finding Gateway Chart Location ==="
# Look for gateway chart
GATEWAY_CHART_DIRS=$(find . -name "gateway" -type d)
if [ -z "$GATEWAY_CHART_DIRS" ]; then
    echo "No gateway directory found. Checking for remote chart references..."
    grep -A 10 -B 5 "chart.*gateway\|gateway.*chart" coreservices-helmfile.yaml.gotmpl || echo "No chart references found"
else
    for chart_dir in $GATEWAY_CHART_DIRS; do
        echo "Found gateway chart at: $chart_dir"
        
        if [ -f "$chart_dir/Chart.yaml" ]; then
            echo -e "\n=== Chart.yaml content ==="
            cat "$chart_dir/Chart.yaml"
            
            echo -e "\n=== Chart templates ==="
            if [ -d "$chart_dir/templates" ]; then
                ls -la "$chart_dir/templates/"
                
                echo -e "\n=== Checking for ServiceAccount template ==="
                if [ -f "$chart_dir/templates/serviceaccount.yaml" ]; then
                    echo "ServiceAccount template content:"
                    cat "$chart_dir/templates/serviceaccount.yaml"
                else
                    echo "No serviceaccount.yaml found. Checking other templates for ServiceAccount references:"
                    find "$chart_dir/templates" -name "*.yaml" -exec grep -l "ServiceAccount\|serviceAccount" {} \; 2>/dev/null
                    
                    # Show the problematic template content
                    find "$chart_dir/templates" -name "*.yaml" -exec grep -H -A 5 -B 5 "ServiceAccount\|serviceAccount" {} \; 2>/dev/null
                fi
                
                echo -e "\n=== Checking deployment template ==="
                if [ -f "$chart_dir/templates/deployment.yaml" ]; then
                    echo "ServiceAccount references in deployment:"
                    grep -n -A 3 -B 3 "serviceAccount" "$chart_dir/templates/deployment.yaml" || echo "No serviceAccount in deployment"
                fi
            fi
            
            echo -e "\n=== Chart values.yaml ==="
            if [ -f "$chart_dir/values.yaml" ]; then
                echo "ServiceAccount section in values.yaml:"
                grep -A 10 -B 5 "serviceAccount" "$chart_dir/values.yaml" || echo "No serviceAccount in values.yaml"
            fi
        fi
    done
fi

echo -e "\n=== 3. Checking for Values Files ==="
# Look for values files that might contain serviceAccount configuration
find . -name "*values*.yaml" -o -name "*values*.yml" | while read values_file; do
    if grep -q "serviceAccount" "$values_file" 2>/dev/null; then
        echo "ServiceAccount found in: $values_file"
        grep -A 10 -B 5 "serviceAccount" "$values_file"
        echo "---"
    fi
done

echo -e "\n=== 4. Generating Helmfile Template for Debugging ==="
echo "Attempting to generate template to see the actual values being passed..."

# Try to generate the template to see what's being generated
if command -v helmfile >/dev/null 2>&1; then
    echo "Running helmfile template for gateway only..."
    helmfile -f coreservices-helmfile.yaml.gotmpl --selector name=gateway template 2>&1 | head -100
else
    echo "Helmfile not found. Please install helmfile or run manually:"
    echo "helmfile -f coreservices-helmfile.yaml.gotmpl --selector name=gateway template"
fi

echo -e "\n=== 5. Summary and Next Steps ==="
echo "The error suggests the ServiceAccount template is using:"
echo "  name: {{ .Values.serviceAccount }}"
echo "Instead of:"
echo "  name: {{ .Values.serviceAccount.name }}"
echo ""
echo "Or the values are structured incorrectly."
echo ""
echo "To fix this, we need to either:"
echo "1. Fix the ServiceAccount template to properly access the name field"
echo "2. Change the values structure to match what the template expects"