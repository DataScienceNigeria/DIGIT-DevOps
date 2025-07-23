#!/bin/bash

echo "=== Examining Helmfile Configuration for Gateway ==="

cd deploy-as-code/charts/core-services

echo "Current directory: $(pwd)"

# Check the helmfile configuration
if [ -f "coreservices-helmfile.yaml.gotmpl" ]; then
    echo -e "\n=== Full Gateway Configuration in Helmfile ==="
    # Get the full gateway configuration block
    awk '/name: gateway/,/^[[:space:]]*-/ {print} /name: gateway/,/^$/ {if (/^$/) exit}' coreservices-helmfile.yaml.gotmpl
    
    echo -e "\n=== Looking for Chart Path ==="
    grep -A 30 "name: gateway" coreservices-helmfile.yaml.gotmpl | grep -E "chart:|path:"
    
    echo -e "\n=== Looking for Values Configuration ==="
    grep -A 50 "name: gateway" coreservices-helmfile.yaml.gotmpl | grep -E "values:|valuesTemplate:"
fi

# Check if there's a default configuration
echo -e "\n=== Checking for Default Configuration ==="
grep -A 20 -B 5 "default:" coreservices-helmfile.yaml.gotmpl

# Look for any values files specifically for gateway
echo -e "\n=== Looking for Gateway Values Files ==="
find .. -name "*gateway*" -type f | grep -E "\.(yaml|yml)$"

# Check if there are environment-specific values
echo -e "\n=== Checking for Environment Values ==="
find .. -name "*values*" -type f | head -10

echo -e "\n=== Checking the Actual Helmfile Command Used ==="
echo "Based on your error, you might be running:"
echo "helmfile -f coreservices-helmfile.yaml.gotmpl apply"
echo ""
echo "Let's see what the template would generate:"
echo "Try running: helmfile -f coreservices-helmfile.yaml.gotmpl template | grep -A 20 -B 5 ServiceAccount"