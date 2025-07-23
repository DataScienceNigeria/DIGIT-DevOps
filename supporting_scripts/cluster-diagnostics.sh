#!/bin/bash

echo "=== Kubernetes Cluster Diagnostics ==="
echo "Checking why all pods are in Pending status..."
echo

echo "1. Checking Node Status:"
kubectl get nodes -o wide
echo

echo "2. Checking Node Conditions:"
kubectl describe nodes | grep -A 10 "Conditions:"
echo

echo "3. Checking Node Resources:"
kubectl top nodes 2>/dev/null || echo "Metrics server not available"
echo

echo "4. Checking Pod Events (last 10 pending pods):"
kubectl get events --all-namespaces --field-selector reason=FailedScheduling --sort-by='.lastTimestamp' | tail -10
echo

echo "5. Checking Specific Pod Details (sample from backbone namespace):"
SAMPLE_POD=$(kubectl get pods -n backbone -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$SAMPLE_POD" ]; then
    echo "Describing pod: $SAMPLE_POD"
    kubectl describe pod $SAMPLE_POD -n backbone | grep -A 20 "Events:"
else
    echo "No pods found in backbone namespace"
fi
echo

echo "6. Checking Storage Classes:"
kubectl get storageclass
echo

echo "7. Checking PersistentVolumes:"
kubectl get pv
echo

echo "8. Checking PersistentVolumeClaims:"
kubectl get pvc --all-namespaces
echo

echo "9. Checking CNI/Network Status:"
kubectl get pods -n kube-system | grep -E "(calico|flannel|weave|cilium|cni)"
echo

echo "10. Checking Taints on Nodes:"
kubectl get nodes -o json | jq -r '.items[] | select(.spec.taints != null) | .metadata.name + ": " + (.spec.taints | tostring)'
echo

echo "11. Checking Node Capacity vs Allocatable:"
kubectl describe nodes | grep -A 5 -B 5 "Allocatable\|Capacity"
echo

echo "12. Checking if nodes are cordoned:"
kubectl get nodes | grep SchedulingDisabled
echo

echo "=== Diagnostics Complete ==="