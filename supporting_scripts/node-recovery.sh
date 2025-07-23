#!/bin/bash

echo "=== Kubernetes Node Recovery Script ==="
echo "Diagnosing and fixing missing nodes issue..."
echo

# Function to check cluster type
check_cluster_type() {
    echo "1. Identifying Cluster Type:"
    
    # Check for EKS
    if kubectl get configmap aws-auth -n kube-system >/dev/null 2>&1; then
        echo "   ✓ Detected: Amazon EKS cluster"
        CLUSTER_TYPE="EKS"
    # Check for kops
    elif kubectl get nodes -o jsonpath='{.items[*].metadata.labels}' 2>/dev/null | grep -q "kops.k8s.io"; then
        echo "   ✓ Detected: kops cluster"
        CLUSTER_TYPE="KOPS"
    # Check for kubeadm
    elif kubectl get configmap kubeadm-config -n kube-system >/dev/null 2>&1; then
        echo "   ✓ Detected: kubeadm cluster"
        CLUSTER_TYPE="KUBEADM"
    # Check for managed services
    elif kubectl get nodes -o jsonpath='{.items[*].spec.providerID}' 2>/dev/null | grep -q "gce://"; then
        echo "   ✓ Detected: Google GKE cluster"
        CLUSTER_TYPE="GKE"
    elif kubectl get nodes -o jsonpath='{.items[*].spec.providerID}' 2>/dev/null | grep -q "azure://"; then
        echo "   ✓ Detected: Azure AKS cluster"
        CLUSTER_TYPE="AKS"
    else
        echo "   ? Unknown cluster type"
        CLUSTER_TYPE="UNKNOWN"
    fi
    echo
}

# Function to check AWS resources for EKS
check_aws_resources() {
    echo "2. Checking AWS Resources (if applicable):"
    
    if command -v aws >/dev/null 2>&1; then
        echo "   Checking EKS cluster status..."
        aws eks describe-cluster --name $(kubectl config current-context | cut -d'/' -f2 2>/dev/null || echo "unknown") --region $(aws configure get region 2>/dev/null || echo "us-east-1") 2>/dev/null || echo "   Could not describe EKS cluster"
        
        echo "   Checking Auto Scaling Groups..."
        aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[?contains(Tags[?Key==`kubernetes.io/cluster/`].Value, `owned`)].[AutoScalingGroupName,DesiredCapacity,MinSize,MaxSize]' --output table 2>/dev/null || echo "   Could not list Auto Scaling Groups"
        
        echo "   Checking EC2 instances..."
        aws ec2 describe-instances --filters "Name=tag:kubernetes.io/cluster/*,Values=owned" --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType]' --output table 2>/dev/null || echo "   Could not list EC2 instances"
    else
        echo "   AWS CLI not available"
    fi
    echo
}

# Function to check cluster components
check_cluster_components() {
    echo "3. Checking Cluster Components:"
    
    echo "   Control plane pods:"
    kubectl get pods -n kube-system | grep -E "(kube-apiserver|kube-controller-manager|kube-scheduler|etcd)" || echo "   No control plane pods found"
    
    echo "   CNI pods:"
    kubectl get pods -n kube-system | grep -E "(calico|flannel|weave|cilium|aws-node|kube-proxy)" || echo "   No CNI pods found"
    
    echo "   DNS pods:"
    kubectl get pods -n kube-system | grep -E "(coredns|kube-dns)" || echo "   No DNS pods found"
    echo
}

# Function to provide recovery steps
provide_recovery_steps() {
    echo "4. Recovery Steps Based on Cluster Type:"
    echo
    
    case $CLUSTER_TYPE in
        "EKS")
            echo "   EKS Cluster Recovery:"
            echo "   1. Check if node groups exist:"
            echo "      aws eks describe-nodegroup --cluster-name YOUR_CLUSTER_NAME --nodegroup-name YOUR_NODEGROUP_NAME"
            echo
            echo "   2. If node group exists but has 0 desired capacity:"
            echo "      aws eks update-nodegroup-config --cluster-name YOUR_CLUSTER_NAME --nodegroup-name YOUR_NODEGROUP_NAME --scaling-config desiredSize=2,maxSize=3,minSize=1"
            echo
            echo "   3. If no node groups exist, create one:"
            echo "      aws eks create-nodegroup --cluster-name YOUR_CLUSTER_NAME --nodegroup-name worker-nodes --instance-types t3.medium --ami-type AL2_x86_64 --capacity-type ON_DEMAND --scaling-config minSize=1,maxSize=3,desiredSize=2 --subnets subnet-xxx subnet-yyy --node-role arn:aws:iam::ACCOUNT:role/NodeInstanceRole"
            echo
            echo "   4. Check Auto Scaling Group:"
            echo "      aws autoscaling update-auto-scaling-group --auto-scaling-group-name YOUR_ASG_NAME --desired-capacity 2"
            ;;
        "KOPS")
            echo "   kops Cluster Recovery:"
            echo "   1. Check instance groups:"
            echo "      kops get instancegroups"
            echo
            echo "   2. Edit instance group to increase size:"
            echo "      kops edit instancegroup nodes"
            echo "      # Set minSize and maxSize to desired values"
            echo
            echo "   3. Apply changes:"
            echo "      kops update cluster --yes"
            echo "      kops rolling-update cluster --yes"
            ;;
        "KUBEADM")
            echo "   kubeadm Cluster Recovery:"
            echo "   1. Check if worker nodes are running:"
            echo "      # SSH to worker nodes and check if kubelet is running"
            echo "      sudo systemctl status kubelet"
            echo
            echo "   2. If nodes exist but not joined, rejoin them:"
            echo "      # On master node, get join command:"
            echo "      kubeadm token create --print-join-command"
            echo "      # Run the output command on worker nodes"
            echo
            echo "   3. If no worker nodes exist, provision new ones and join them"
            ;;
        "GKE")
            echo "   GKE Cluster Recovery:"
            echo "   1. Check node pools:"
            echo "      gcloud container node-pools list --cluster=YOUR_CLUSTER_NAME"
            echo
            echo "   2. Resize node pool:"
            echo "      gcloud container clusters resize YOUR_CLUSTER_NAME --num-nodes=2"
            ;;
        "AKS")
            echo "   AKS Cluster Recovery:"
            echo "   1. Check node pools:"
            echo "      az aks nodepool list --cluster-name YOUR_CLUSTER_NAME --resource-group YOUR_RG"
            echo
            echo "   2. Scale node pool:"
            echo "      az aks nodepool scale --cluster-name YOUR_CLUSTER_NAME --resource-group YOUR_RG --name YOUR_NODEPOOL --node-count 2"
            ;;
        *)
            echo "   Generic Recovery Steps:"
            echo "   1. Check your cloud provider's console for VM instances"
            echo "   2. Ensure worker nodes are running and have network connectivity"
            echo "   3. Check if kubelet service is running on worker nodes"
            echo "   4. Verify worker nodes can reach the API server"
            echo "   5. Check if nodes need to be re-joined to the cluster"
            ;;
    esac
    echo
}

# Function to provide immediate workarounds
provide_workarounds() {
    echo "5. Immediate Workarounds (TEMPORARY ONLY):"
    echo
    echo "   Option A: Allow scheduling on control plane (NOT for production):"
    echo "   kubectl taint nodes --all node-role.kubernetes.io/control-plane-"
    echo "   kubectl taint nodes --all node-role.kubernetes.io/master-"
    echo
    echo "   Option B: Check if any nodes exist but are cordoned:"
    echo "   kubectl get nodes"
    echo "   kubectl uncordon NODE_NAME"
    echo
    echo "   Option C: If using a single-node cluster for testing:"
    echo "   kubectl taint nodes --all node-role.kubernetes.io/control-plane-"
    echo
}

# Function to check cluster context
check_cluster_context() {
    echo "6. Cluster Context Information:"
    echo "   Current context: $(kubectl config current-context)"
    echo "   Current cluster: $(kubectl config view --minify -o jsonpath='{.clusters[0].name}')"
    echo "   API Server: $(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
    echo
}

# Main execution
main() {
    check_cluster_type
    check_aws_resources
    check_cluster_components
    check_cluster_context
    provide_recovery_steps
    provide_workarounds
    
    echo "=== Next Steps ==="
    echo "1. Identify your cluster type and follow the appropriate recovery steps above"
    echo "2. If this is a managed cluster (EKS/GKE/AKS), check your cloud provider console"
    echo "3. If this is a self-managed cluster, ensure worker nodes are running and joined"
    echo "4. For immediate testing, you can use the workarounds (not recommended for production)"
    echo
    echo "After nodes are available, your DIGIT services should start automatically."
    echo "=== Recovery Script Complete ==="
}

# Run the main function
main