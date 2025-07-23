#!/bin/bash

echo "=== Debugging Gateway Values Configuration ==="

cd /home/ubuntu/DPI/DIGIT-DevOps/deploy-as-code/charts/core-services

echo "Current directory: $(pwd)"

echo -e "\n=== 1. Checking Gateway Chart Values ==="
if [ -f "gateway/values.yaml" ]; then
    echo "Gateway chart values.yaml:"
    cat gateway/values.yaml | head -50
else
    echo "No gateway/values.yaml found"
fi

echo -e "\n=== 2. Checking Environment Values Files ==="
if [ -f "../environments/env.yaml" ]; then
    echo "Environment values (env.yaml) - Gateway section:"
    grep -A 20 "^gateway:" ../environments/env.yaml || echo "No gateway section found in env.yaml"
else
    echo "No env.yaml found"
fi

if [ -f "../environments/env-secrets.yaml" ]; then
    echo -e "\nEnvironment secrets (env-secrets.yaml) - Gateway section:"
    grep -A 10 "^gateway:" ../environments/env-secrets.yaml || echo "No gateway section found in env-secrets.yaml"
else
    echo "No env-secrets.yaml found"
fi

echo -e "\n=== 3. Using Helm Debug to See Actual Values ==="
echo "Running helm template with debug to see what values are being passed..."

# Use helm template with debug to see the actual values
cd gateway
helm template gateway . --debug --dry-run 2>&1 | head -100

echo -e "\n=== 4. Checking Helmfile Values Generation ==="
cd ..
echo "Checking what helmfile generates for values..."

# Try to see what helmfile is generating for values
helmfile -f coreservices-helmfile.yaml.gotmpl --selector name=gateway build 2>&1 | head -50

echo -e "\n=== 5. Manual Values Check ==="
echo "Let's check if the image section exists in the merged values..."

# Create a simple test template to see what values are available
cat > test-values.yaml << 'EOF'
# Test values to see what's available
image:
  repository: "egovio/gateway"
  tag: "spring-cloud-gateway-6df77bec7c-15"
  pullPolicy: "IfNotPresent"
serviceAccount:
  create: true
  name: gateway-service-account
replicas: 1
httpPort: 8080
EOF

echo "Testing with manual values:"
cd gateway
helm template gateway . -f ../test-values.yaml --debug 2>&1 | grep -A 5 -B 5 "image:" || echo "No image section found in output"