#!/bin/bash

echo "=== Complete Kubernetes Cleanup and Reinitialization ==="
echo "This script will:"
echo "1. Delete all Helm releases"
echo "2. Clean up Kubernetes resources"
echo "3. Reset EKS node groups"
echo "4. Reinitialize the DIGIT deployment"
echo

# Configuration
CLUSTER_NAME="digit-lts-dsn"
REGION="ap-south-1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to confirm action
confirm_action() {
    echo "⚠️  WARNING: This will delete ALL resources in your cluster!"
    echo "This includes:"
    echo "- All Helm releases in all namespaces"
    echo "- All pods, services, deployments"
    echo "- All PersistentVolumeClaims (data will be lost)"
    echo "- EKS node groups will be recreated"
    echo
    read -p "Are you sure you want to proceed? (type 'YES' to confirm): " confirmation
    
    if [ "$confirmation" != "YES" ]; then
        echo "❌ Operation cancelled"
        exit 1
    fi
    echo "✅ Proceeding with cleanup..."
    echo
}

# Function to backup current configuration
backup_configuration() {
    echo "=== 1. Backing up current configuration ==="
    
    BACKUP_DIR="/tmp/digit-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    echo "Creating backup at: $BACKUP_DIR"
    
    # Backup Helm releases
    echo "Backing up Helm releases..."
    helm list --all-namespaces > "$BACKUP_DIR/helm-releases.txt" 2>/dev/null || echo "No Helm releases to backup"
    
    # Backup Kubernetes resources
    echo "Backing up Kubernetes resources..."
    kubectl get all --all-namespaces > "$BACKUP_DIR/k8s-resources.txt" 2>/dev/null || echo "No K8s resources to backup"
    
    # Backup PVCs (for reference)
    echo "Backing up PVC information..."
    kubectl get pvc --all-namespaces > "$BACKUP_DIR/pvcs.txt" 2>/dev/null || echo "No PVCs to backup"
    
    # Backup current node information
    echo "Backing up node information..."
    kubectl get nodes -o wide > "$BACKUP_DIR/nodes.txt" 2>/dev/null || echo "No nodes to backup"
    
    echo "✅ Backup completed at: $BACKUP_DIR"
    echo
}

# Function to delete all Helm releases
cleanup_helm_releases() {
    echo "=== 2. Cleaning up Helm releases ==="
    
    # Get all namespaces with Helm releases
    NAMESPACES=$(helm list --all-namespaces --short 2>/dev/null | awk '{print $2}' | sort | uniq)
    
    if [ -z "$NAMESPACES" ]; then
        echo "No Helm releases found"
        return
    fi
    
    echo "Found Helm releases in namespaces: $NAMESPACES"
    
    for namespace in $NAMESPACES; do
        echo "Cleaning up releases in namespace: $namespace"
        
        # Get all releases in this namespace
        RELEASES=$(helm list -n "$namespace" --short 2>/dev/null)
        
        for release in $RELEASES; do
            echo "  Deleting release: $release"
            helm uninstall "$release" -n "$namespace" --timeout 300s 2>/dev/null || echo "  Failed to delete $release"
        done
    done
    
    echo "✅ Helm releases cleanup completed"
    echo
}

# Function to cleanup Kubernetes resources
cleanup_kubernetes_resources() {
    echo "=== 3. Cleaning up Kubernetes resources ==="
    
    # List of namespaces to clean (excluding system namespaces)
    CLEANUP_NAMESPACES="egov backbone monitoring cert-manager"
    
    for namespace in $CLEANUP_NAMESPACES; do
        if kubectl get namespace "$namespace" >/dev/null 2>&1; then
            echo "Cleaning up namespace: $namespace"
            
            # Delete all resources in namespace (except PVs which are cluster-scoped)
            echo "  Deleting all resources in $namespace..."
            kubectl delete all --all -n "$namespace" --timeout=300s 2>/dev/null || echo "  Some resources couldn't be deleted"
            
            # Delete PVCs (this will delete data!)
            echo "  Deleting PVCs in $namespace..."
            kubectl delete pvc --all -n "$namespace" --timeout=300s 2>/dev/null || echo "  No PVCs to delete"
            
            # Delete secrets and configmaps
            echo "  Deleting secrets and configmaps in $namespace..."
            kubectl delete secrets --all -n "$namespace" --timeout=60s 2>/dev/null || echo "  No secrets to delete"
            kubectl delete configmaps --all -n "$namespace" --timeout=60s 2>/dev/null || echo "  No configmaps to delete"
            
            # Delete the namespace itself
            echo "  Deleting namespace: $namespace"
            kubectl delete namespace "$namespace" --timeout=300s 2>/dev/null || echo "  Namespace deletion initiated"
        else
            echo "Namespace $namespace doesn't exist, skipping"
        fi
    done
    
    # Clean up any remaining PVs
    echo "Cleaning up orphaned PersistentVolumes..."
    kubectl get pv --no-headers 2>/dev/null | awk '$5=="Released" {print $1}' | xargs -r kubectl delete pv 2>/dev/null || echo "No orphaned PVs to clean"
    
    echo "✅ Kubernetes resources cleanup completed"
    echo
}

# Function to reset EKS node groups
reset_eks_nodegroups() {
    echo "=== 4. Resetting EKS node groups ==="
    
    # Check if AWS CLI is available
    if ! command -v aws >/dev/null 2>&1; then
        echo "❌ AWS CLI not found. Please install AWS CLI to manage node groups"
        return 1
    fi
    
    # List existing node groups
    echo "Checking existing node groups..."
    NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$REGION" --output text --query 'nodegroups[]' 2>/dev/null)
    
    if [ -n "$NODE_GROUPS" ]; then
        echo "Found existing node groups: $NODE_GROUPS"
        
        for nodegroup in $NODE_GROUPS; do
            echo "Deleting node group: $nodegroup"
            aws eks delete-nodegroup \
                --cluster-name "$CLUSTER_NAME" \
                --nodegroup-name "$nodegroup" \
                --region "$REGION" 2>/dev/null || echo "Failed to delete $nodegroup"
        done
        
        echo "Waiting for node groups to be deleted..."
        sleep 60
        
        # Wait for deletion to complete
        for i in {1..10}; do
            REMAINING=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$REGION" --output text --query 'nodegroups[]' 2>/dev/null)
            if [ -z "$REMAINING" ]; then
                echo "✅ All node groups deleted"
                break
            else
                echo "Still deleting... remaining: $REMAINING (attempt $i/10)"
                sleep 30
            fi
        done
    else
        echo "No existing node groups found"
    fi
    
    echo "✅ Node groups reset completed"
    echo
}

# Function to create new node group
create_new_nodegroup() {
    echo "=== 5. Creating new node group ==="
    
    # Get cluster subnets
    SUBNETS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.resourcesVpcConfig.subnetIds' --output text 2>/dev/null)
    
    if [ -z "$SUBNETS" ]; then
        echo "❌ Could not retrieve cluster subnets"
        return 1
    fi
    
    echo "Using subnets: $SUBNETS"
    
    # Check for existing node instance role
    NODE_ROLE=$(aws iam list-roles --query 'Roles[?contains(RoleName, `NodeInstanceRole`) || contains(RoleName, `node`) || contains(RoleName, `worker`)].Arn' --output text 2>/dev/null | head -1)
    
    if [ -z "$NODE_ROLE" ]; then
        echo "Creating node instance role..."
        
        # Create trust policy
        cat > /tmp/node-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

        # Create role
        aws iam create-role \
            --role-name "${CLUSTER_NAME}-node-instance-role" \
            --assume-role-policy-document file:///tmp/node-trust-policy.json \
            --region "$REGION" 2>/dev/null || echo "Role might already exist"

        # Attach policies
        aws iam attach-role-policy \
            --role-name "${CLUSTER_NAME}-node-instance-role" \
            --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy \
            --region "$REGION" 2>/dev/null

        aws iam attach-role-policy \
            --role-name "${CLUSTER_NAME}-node-instance-role" \
            --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy \
            --region "$REGION" 2>/dev/null

        aws iam attach-role-policy \
            --role-name "${CLUSTER_NAME}-node-instance-role" \
            --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly \
            --region "$REGION" 2>/dev/null

        NODE_ROLE="arn:aws:iam::331029743701:role/${CLUSTER_NAME}-node-instance-role"
        
        echo "Waiting for role to be available..."
        sleep 30
    else
        echo "Using existing node role: $NODE_ROLE"
    fi
    
    # Create new node group
    echo "Creating new node group..."
    aws eks create-nodegroup \
        --cluster-name "$CLUSTER_NAME" \
        --nodegroup-name "worker-nodes-$(date +%Y%m%d)" \
        --region "$REGION" \
        --instance-types t3.medium \
        --ami-type AL2_x86_64 \
        --capacity-type ON_DEMAND \
        --scaling-config minSize=1,maxSize=5,desiredSize=3 \
        --subnets $(echo $SUBNETS | tr '\t' ' ') \
        --node-role "$NODE_ROLE" \
        --disk-size 30 \
        --tags '{"Environment":"development","Project":"digit-lts","CreatedBy":"cleanup-script"}'

    if [ $? -eq 0 ]; then
        echo "✅ Node group creation initiated"
        echo "⏳ Waiting for nodes to be ready (this may take 5-10 minutes)..."
        
        # Wait for nodes to be ready
        for i in {1..20}; do
            READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
            echo "Ready nodes: $READY_NODES (check $i/20)"
            
            if [ "$READY_NODES" -ge "2" ]; then
                echo "✅ Nodes are ready!"
                break
            fi
            
            sleep 30
        done
    else
        echo "❌ Failed to create node group"
        return 1
    fi
    
    echo
}

# Function to wait for cluster to be ready
wait_for_cluster_ready() {
    echo "=== 6. Waiting for cluster to be ready ==="
    
    echo "Waiting for system pods to start..."
    for i in {1..10}; do
        COREDNS_READY=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c "Running" || echo "0")
        echo "CoreDNS pods ready: $COREDNS_READY (check $i/10)"
        
        if [ "$COREDNS_READY" -ge "1" ]; then
            echo "✅ Cluster is ready for deployments!"
            break
        fi
        
        sleep 30
    done
    
    echo
}

# Function to reinitialize DIGIT deployment
reinitialize_digit() {
    echo "=== 7. Reinitializing DIGIT deployment ==="
    
    # Navigate to the correct directory
    HELMFILE_DIR="/home/ubuntu/DPI/DIGIT-DevOps/deploy-as-code"
    
    if [ ! -d "$HELMFILE_DIR" ]; then
        echo "❌ DIGIT deployment directory not found: $HELMFILE_DIR"
        return 1
    fi
    
    cd "$HELMFILE_DIR"
    echo "Working directory: $(pwd)"
    
    # Deploy backbone services first
    echo "Deploying backbone services..."
    if [ -f "digit-helmfile.yaml" ]; then
        helmfile -f digit-helmfile.yaml apply --selector tier=backbone --timeout 600
        
        echo "Waiting for backbone services to be ready..."
        sleep 120
        
        # Deploy core services
        echo "Deploying core services..."
        helmfile -f digit-helmfile.yaml apply --selector tier=core --timeout 600
        
    else
        echo "❌ digit-helmfile.yaml not found"
        echo "Available files:"
        ls -la
        return 1
    fi
    
    echo "✅ DIGIT reinitialization completed"
    echo
}

# Function to verify deployment
verify_deployment() {
    echo "=== 8. Verifying deployment ==="
    
    echo "Checking nodes:"
    kubectl get nodes -o wide
    
    echo -e "\nChecking namespaces:"
    kubectl get namespaces
    
    echo -e "\nChecking pods in all namespaces:"
    kubectl get pods --all-namespaces | head -20
    
    echo -e "\nChecking services in egov namespace:"
    kubectl get services -n egov 2>/dev/null || echo "egov namespace not ready yet"
    
    echo -e "\nChecking Helm releases:"
    helm list --all-namespaces
    
    echo -e "\nCluster summary:"
    echo "- Nodes: $(kubectl get nodes --no-headers 2>/dev/null | wc -l)"
    echo "- Namespaces: $(kubectl get namespaces --no-headers 2>/dev/null | wc -l)"
    echo "- Pods: $(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l)"
    echo "- Services: $(kubectl get services --all-namespaces --no-headers 2>/dev/null | wc -l)"
    
    echo "✅ Verification completed"
    echo
}

# Function to provide next steps
provide_next_steps() {
    echo "=== 9. Next Steps ==="
    echo
    echo "🎉 Cleanup and reinitialization completed!"
    echo
    echo "What to do next:"
    echo "1. Monitor pod startup: kubectl get pods --all-namespaces -w"
    echo "2. Check service status: kubectl get services -n egov"
    echo "3. Access applications once ingress is ready"
    echo "4. Check logs if any issues: kubectl logs -n egov <pod-name>"
    echo
    echo "Useful commands:"
    echo "- Check all pods: kubectl get pods --all-namespaces"
    echo "- Check specific namespace: kubectl get all -n egov"
    echo "- Check events: kubectl get events --all-namespaces --sort-by='.lastTimestamp'"
    echo "- Check ingress: kubectl get ingress --all-namespaces"
    echo
    echo "If you encounter issues:"
    echo "- Check node resources: kubectl top nodes"
    echo "- Check pod resources: kubectl top pods --all-namespaces"
    echo "- Describe problematic pods: kubectl describe pod <pod-name> -n <namespace>"
    echo
}

# Main execution
main() {
    echo "Starting complete cleanup and reinitialization..."
    echo "Cluster: $CLUSTER_NAME"
    echo "Region: $REGION"
    echo
    
    confirm_action
    backup_configuration
    cleanup_helm_releases
    cleanup_kubernetes_resources
    reset_eks_nodegroups
    create_new_nodegroup
    wait_for_cluster_ready
    reinitialize_digit
    verify_deployment
    provide_next_steps
    
    echo "=== Complete Cleanup and Reinitialization Finished ==="
    echo "Check the verification output above and monitor your deployments."
}

# Run the main function
main