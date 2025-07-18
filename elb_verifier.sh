#!/bin/bash

echo "=== LoadBalancer Details ==="
kubectl get svc ingress-nginx-controller -n backbone -o wide

echo -e "\n=== LoadBalancer DNS Resolution ==="
LB_HOST=$(kubectl get svc ingress-nginx-controller -n backbone -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "LoadBalancer hostname: $LB_HOST"
nslookup $LB_HOST

echo -e "\n=== Domain DNS Resolution ==="
nslookup certi-verse.com

echo -e "\n=== Testing LoadBalancer Direct Access ==="
curl -I http://$LB_HOST --connect-timeout 10

echo -e "\n=== Testing Domain HTTP Access ==="
curl -I http://certi-verse.com --connect-timeout 10

echo -e "\n=== Testing Domain HTTPS Access ==="
curl -I https://certi-verse.com --connect-timeout 10

echo -e "\n=== Checking Ingress Resources ==="
kubectl get ingress -A

echo -e "\n=== Checking Ingress Controller Logs ==="
kubectl logs -n backbone deployment/ingress-nginx-controller --tail=10