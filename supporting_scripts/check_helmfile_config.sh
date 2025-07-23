#!/bin/bash

echo "=== Enhanced Helmfile Configuration Analysis ==="
echo "Checking DIGIT core services configuration..."
echo

# Get the script directory and navigate to the correct location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Script directory: $SCRIPT_DIR"

# Navigate to the correct directory based on the known structure
if [ -f "$SCRIPT_DIR/../deploy-as-code/charts/core-services/coreservices-helmfile.yaml.gotmpl" ]; then
    cd "$SCRIPT_DIR/../deploy-as-code/charts/core-services"
    echo "✓ Found helmfile at: $(pwd)/coreservices-helmfile.yaml.gotmpl"
elif [ -f "/home/ubuntu/DPI/DIGIT-DevOps/deploy-as-code/charts/core-services/coreservices-helmfile.yaml.gotmpl" ]; then
    cd "/home/ubuntu/DPI/DIGIT-DevOps/deploy-as-code/charts/core-services"
    echo "✓ Found helmfile at: $(pwd)/coreservices-helmfile.yaml.gotmpl"
else
    echo "❌ Cannot find coreservices-helmfile.yaml.gotmpl"
    echo "Searching for the file..."
    find /home/ubuntu/DPI/DIGIT-DevOps -name "coreservices-helmfile.yaml.gotmpl" 2>/dev/null
    echo "Current directory: $(pwd)"
    echo "Available files in current directory:"
    ls -la
    exit 1
fi

echo "✓ Current working directory: $(pwd)"
echo

# Function to check helmfile syntax
check_helmfile_syntax() {
    echo "=== 1. Checking Helmfile Syntax ==="
    
    if [ -f "coreservices-helmfile.yaml.gotmpl" ]; then
        echo "✓ Found coreservices-helmfile.yaml.gotmpl"
        
        # Show file size and basic info
        echo "File info: $(ls -lh coreservices-helmfile.yaml.gotmpl)"
        
        # Check if helmfile can parse the file
        echo "Checking if Helmfile can parse the configuration..."
        helmfile -f coreservices-helmfile.yaml.gotmpl list >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "✅ Helmfile syntax is valid"
        else
            echo "❌ Helmfile syntax errors detected"
            echo "Running helmfile list to show errors:"
            helmfile -f coreservices-helmfile.yaml.gotmpl list
        fi
    else
        echo "❌ coreservices-helmfile.yaml.gotmpl not found in current directory"
        return 1
    fi
    echo
}

# Function to show helmfile content summary
show_helmfile_summary() {
    echo "=== 1.5. Helmfile Content Summary ==="
    
    if [ -f "coreservices-helmfile.yaml.gotmpl" ]; then
        echo "Total lines: $(wc -l < coreservices-helmfile.yaml.gotmpl)"
        
        echo -e "\nEnvironments section:"
        grep -A 10 "^environments:" coreservices-helmfile.yaml.gotmpl || echo "No environments section found"
        
        echo -e "\nTemplates section:"
        grep -A 5 "^templates:" coreservices-helmfile.yaml.gotmpl || echo "No templates section found"
        
        echo -e "\nReleases count:"
        grep -c "^[[:space:]]*- name:" coreservices-helmfile.yaml.gotmpl || echo "0"
        
        echo -e "\nFirst few releases:"
        grep "^[[:space:]]*- name:" coreservices-helmfile.yaml.gotmpl | head -5
    fi
    echo
}

# Function to analyze gateway configuration
analyze_gateway_config() {
    echo "=== 2. Gateway Configuration Analysis ==="
    
    if grep -q "name: gateway" coreservices-helmfile.yaml.gotmpl; then
        echo "✓ Found gateway service definition"
        
        echo -e "\n--- Gateway Release Configuration ---"
        awk '/- name: gateway/,/^[[:space:]]*- name:/ {if (/^[[:space:]]*- name:/ && !/- name: gateway/) exit; print}' coreservices-helmfile.yaml.gotmpl
        
        echo -e "\n--- Checking Gateway Chart Reference ---"
        awk '/- name: gateway/,/^[[:space:]]*- name:/ {if (/^[[:space:]]*- name:/ && !/- name: gateway/) exit; if (/chart:/) print}' coreservices-helmfile.yaml.gotmpl
        
        echo -e "\n--- Checking Gateway Values ---"
        awk '/- name: gateway/,/^[[:space:]]*- name:/ {if (/^[[:space:]]*- name:/ && !/- name: gateway/) exit; if (/values:/) print}' coreservices-helmfile.yaml.gotmpl
        
    else
        echo "❌ No gateway service found in helmfile"
    fi
    echo
}

# Function to check chart references
check_chart_references() {
    echo "=== 3. Chart References Analysis ==="
    
    echo "Checking if common chart exists:"
    if [ -d "../../charts/common" ]; then
        echo "✓ Found common chart at ../../charts/common"
        ls -la ../../charts/common/
        
        echo -e "\nChart.yaml content:"
        cat ../../charts/common/Chart.yaml 2>/dev/null || echo "❌ Chart.yaml not found"
        
        echo -e "\nTemplates directory:"
        ls -la ../../charts/common/templates/ 2>/dev/null || echo "❌ Templates directory not found"
        
        # Check for key template files
        echo -e "\nKey template files:"
        for template in deployment.yaml service.yaml configmap.yaml ingress.yaml; do
            if [ -f "../../charts/common/templates/$template" ]; then
                echo "  ✓ $template exists"
            else
                echo "  ❌ $template missing"
            fi
        done
        
    else
        echo "❌ Common chart not found at ../../charts/common"
        echo "Looking for chart in other locations:"
        find ../.. -name "common" -type d 2>/dev/null
    fi
    echo
}

# Function to check environment files
check_environment_files() {
    echo "=== 4. Environment Files Analysis ==="
    
    echo "Looking for environment files referenced in helmfile:"
    grep -E "values:|environments:" coreservices-helmfile.yaml.gotmpl | head -10
    
    echo -e "\nChecking for environment files:"
    
    # Check for env.yaml
    if [ -f "../environments/env.yaml" ]; then
        echo "✓ Found ../environments/env.yaml"
        echo "File size: $(ls -lh ../environments/env.yaml | awk '{print $5}')"
        echo "First 20 lines:"
        head -20 ../environments/env.yaml
    else
        echo "❌ ../environments/env.yaml not found"
        echo "Looking for env files:"
        find ../.. -name "*env*.yaml" -o -name "*env*.yml" 2>/dev/null | head -5
    fi
    
    # Check for env-secrets.yaml
    if [ -f "../environments/env-secrets.yaml" ]; then
        echo "✓ Found ../environments/env-secrets.yaml"
        echo "File size: $(ls -lh ../environments/env-secrets.yaml | awk '{print $5}')"
    else
        echo "❌ ../environments/env-secrets.yaml not found"
    fi
    echo
}

# Function to check current deployment status
check_deployment_status() {
    echo "=== 5. Current Deployment Status ==="
    
    echo "Helm releases in egov namespace:"
    helm list -n egov 2>/dev/null || echo "❌ Cannot list helm releases"
    
    echo -e "\nKubernetes resources in egov namespace:"
    echo "Deployments:"
    kubectl get deployments -n egov 2>/dev/null || echo "❌ Cannot get deployments"
    
    echo "Services:"
    kubectl get services -n egov 2>/dev/null || echo "❌ Cannot get services"
    
    echo "Pods:"
    kubectl get pods -n egov 2>/dev/null || echo "❌ Cannot get pods"
    
    echo -e "\nNodes status:"
    kubectl get nodes 2>/dev/null || echo "❌ Cannot get nodes"
    echo
}

# Function to check specific service configurations
check_service_configs() {
    echo "=== 6. Service Configuration Summary ==="
    
    echo "Services defined in helmfile:"
    grep -E "^[[:space:]]*- name:" coreservices-helmfile.yaml.gotmpl | sed 's/.*name: /- /' | sort
    
    echo -e "\nTotal services: $(grep -c "^[[:space:]]*- name:" coreservices-helmfile.yaml.gotmpl)"
    
    echo -e "\nChecking for template references:"
    grep -E "<<:" coreservices-helmfile.yaml.gotmpl | head -5
    
    echo -e "\nChecking for dependencies:"
    grep -A 5 "needs:" coreservices-helmfile.yaml.gotmpl | head -10
    echo
}

# Function to check for common issues
check_common_issues() {
    echo "=== 6.5. Common Issues Check ==="
    
    # Check for chart version consistency
    echo "Chart versions used:"
    grep -E "version:" coreservices-helmfile.yaml.gotmpl | sort | uniq -c
    
    # Check for namespace consistency
    echo -e "\nNamespaces used:"
    grep -E "namespace:" coreservices-helmfile.yaml.gotmpl | sort | uniq -c
    
    # Check for missing values files
    echo -e "\nValues files referenced:"
    grep -E "values:" coreservices-helmfile.yaml.gotmpl | grep -E "\\.yaml|\\.yml" | head -5
    
    echo
}

# Function to provide recommendations
provide_recommendations() {
    echo "=== 7. Recommendations ==="
    
    # Check if nodes are available
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    if [ "$NODE_COUNT" -eq "0" ]; then
        echo "🚨 CRITICAL: No Kubernetes nodes available"
        echo "   → Run the EKS node recovery script first"
        echo "   → Command: cd $SCRIPT_DIR && ./eks-node-recovery.sh"
    else
        echo "✅ Nodes are available ($NODE_COUNT nodes)"
    fi
    
    # Check if environment files exist
    if [ ! -f "../environments/env.yaml" ]; then
        echo "🚨 CRITICAL: Environment file missing"
        echo "   → Create ../environments/env.yaml with service configurations"
    fi
    
    # Check if common chart exists
    if [ ! -d "../../charts/common" ]; then
        echo "🚨 CRITICAL: Common chart missing"
        echo "   → Ensure ../../charts/common directory exists with proper templates"
    fi
    
    # Check helmfile syntax
    helmfile -f coreservices-helmfile.yaml.gotmpl list >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "🚨 CRITICAL: Helmfile syntax errors"
        echo "   → Fix YAML syntax in coreservices-helmfile.yaml.gotmpl"
    fi
    
    # Check if releases are deployed but no pods
    HELM_RELEASES=$(helm list -n egov --no-headers 2>/dev/null | wc -l)
    POD_COUNT=$(kubectl get pods -n egov --no-headers 2>/dev/null | wc -l)
    
    if [ "$HELM_RELEASES" -gt "0" ] && [ "$POD_COUNT" -eq "0" ]; then
        echo "🚨 ISSUE: Helm releases exist but no pods are running"
        echo "   → This suggests chart template issues or missing environment values"
        echo "   → Check common chart templates and environment files"
    fi
    
    echo -e "\n📋 Next Steps:"
    echo "1. Fix any CRITICAL issues above"
    echo "2. Ensure EKS nodes are available: cd $SCRIPT_DIR && ./eks-node-recovery.sh"
    echo "3. Run: helmfile -f coreservices-helmfile.yaml.gotmpl apply"
    echo "4. Monitor: kubectl get pods -n egov -w"
    echo
}

# Function to generate debug commands
generate_debug_commands() {
    echo "=== 8. Debug Commands ==="
    echo "Run these commands to debug further:"
    echo
    echo "# Navigate to helmfile directory:"
    echo "cd $(pwd)"
    echo
    echo "# Check helmfile template generation:"
    echo "helmfile -f coreservices-helmfile.yaml.gotmpl template"
    echo
    echo "# Check specific service template:"
    echo "helmfile -f coreservices-helmfile.yaml.gotmpl template --selector name=gateway"
    echo
    echo "# Check helmfile diff:"
    echo "helmfile -f coreservices-helmfile.yaml.gotmpl diff"
    echo
    echo "# Check helm release details:"
    echo "helm get all gateway -n egov"
    echo
    echo "# Check pod events:"
    echo "kubectl get events -n egov --sort-by='.lastTimestamp'"
    echo
    echo "# Check node status:"
    echo "kubectl describe nodes"
    echo
    echo "# Test single service deployment:"
    echo "helm template configmaps ../../charts/common --values ../environments/env.yaml"
    echo
}

# Main execution
main() {
    check_helmfile_syntax
    show_helmfile_summary
    analyze_gateway_config
    check_chart_references
    check_environment_files
    check_deployment_status
    check_service_configs
    check_common_issues
    provide_recommendations
    generate_debug_commands
    
    echo "=== Analysis Complete ==="
    echo "Review the recommendations above and fix any CRITICAL issues."
}

# Run the analysis
main