#!/bin/bash

echo "=== EKS Node Group Recovery for digit-lts-dsn ==="
echo "Checking and fixing node groups..."
echo

CLUSTER_NAME="digit-lts-dsn"
REGION="ap-south-1"

# Function to check existing node groups
check_node_groups() {
    echo "1. Checking existing node groups:"
    
    NODE_GROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --output text --query 'nodegroups[]' 2>/dev/null)
    
    if [ -z "$NODE_GROUPS" ]; then
        echo "   ❌ No node groups found"
        NODE_GROUPS_EXIST=false
    else
        echo "   ✓ Found node groups: $NODE_GROUPS"
        NODE_GROUPS_EXIST=true
        
        # Check each node group status
        for nodegroup in $NODE_GROUPS; do
            echo "   Checking node group: $nodegroup"
            aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $nodegroup --region $REGION --query 'nodegroup.{Status:status,DesiredSize:scalingConfig.desiredSize,MinSize:scalingConfig.minSize,MaxSize:scalingConfig.maxSize,InstanceTypes:instanceTypes[0]}' --output table
        done
    fi
    echo
}

# Function to scale existing node groups
scale_existing_node_groups() {
    if [ "$NODE_GROUPS_EXIST" = true ]; then
        echo "2. Scaling existing node groups:"
        
        for nodegroup in $NODE_GROUPS; do
            echo "   Scaling node group: $nodegroup"
            
            # Get current scaling config
            CURRENT_DESIRED=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $nodegroup --region $REGION --query 'nodegroup.scalingConfig.desiredSize' --output text)
            
            if [ "$CURRENT_DESIRED" = "0" ]; then
                echo "   📈 Scaling up $nodegroup from 0 to 2 nodes..."
                aws eks update-nodegroup-config \
                    --cluster-name $CLUSTER_NAME \
                    --nodegroup-name $nodegroup \
                    --region $REGION \
                    --scaling-config desiredSize=2,maxSize=3,minSize=1
                
                if [ $? -eq 0 ]; then
                    echo "   ✅ Successfully initiated scaling for $nodegroup"
                else
                    echo "   ❌ Failed to scale $nodegroup"
                fi
            else
                echo "   ℹ️  Node group $nodegroup already has $CURRENT_DESIRED desired nodes"
            fi
        done
    else
        echo "2. No existing node groups to scale"
    fi
    echo
}

# Function to create new node group if none exist
create_node_group() {
    if [ "$NODE_GROUPS_EXIST" = false ]; then
        echo "3. Creating new node group:"
        
        # Get subnets from cluster
        SUBNETS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.resourcesVpcConfig.subnetIds' --output text | tr '\t' ',')
        echo "   Using subnets: $SUBNETS"
        
        # Check if node instance role exists
        echo "   Checking for existing node instance role..."
        NODE_ROLE=$(aws iam list-roles --query 'Roles[?contains(RoleName, `NodeInstanceRole`) || contains(RoleName, `node`) || contains(RoleName, `worker`)].Arn' --output text | head -1)
        
        if [ -z "$NODE_ROLE" ]; then
            echo "   ❌ No suitable node instance role found. Creating one..."
            
            # Create node instance role
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

            aws iam create-role \
                --role-name ${CLUSTER_NAME}-node-instance-role \
                --assume-role-policy-document file:///tmp/node-trust-policy.json \
                --region $REGION

            # Attach required policies
            aws iam attach-role-policy \
                --role-name ${CLUSTER_NAME}-node-instance-role \
                --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy \
                --region $REGION

            aws iam attach-role-policy \
                --role-name ${CLUSTER_NAME}-node-instance-role \
                --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy \
                --region $REGION

            aws iam attach-role-policy \
                --role-name ${CLUSTER_NAME}-node-instance-role \
                --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly \
                --region $REGION

            # Wait for role to be available
            echo "   Waiting for role to be available..."
            sleep 30

            NODE_ROLE="arn:aws:iam::331029743701:role/${CLUSTER_NAME}-node-instance-role"
        else
            echo "   ✓ Found existing node role: $NODE_ROLE"
        fi

        echo "   Creating node group 'worker-nodes'..."
        aws eks create-nodegroup \
            --cluster-name $CLUSTER_NAME \
            --nodegroup-name worker-nodes \
            --region $REGION \
            --instance-types t3.medium \
            --ami-type AL2_x86_64 \
            --capacity-type ON_DEMAND \
            --scaling-config minSize=1,maxSize=3,desiredSize=2 \
            --subnets $(echo $SUBNETS | tr ',' ' ') \
            --node-role $NODE_ROLE \
            --disk-size 20 \
            --tags '{"Environment":"development","Project":"digit-lts"}'

        if [ $? -eq 0 ]; then
            echo "   ✅ Successfully initiated node group creation"
            echo "   ⏳ Node group creation will take 3-5 minutes..."
        else
            echo "   ❌ Failed to create node group"
        fi
    else
        echo "3. Node groups already exist, skipping creation"
    fi
    echo
}

# Function to monitor node group status
monitor_node_groups() {
    echo "4. Monitoring node group status:"
    
    if [ "$NODE_GROUPS_EXIST" = true ] || aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --output text --query 'nodegroups[]' >/dev/null 2>&1; then
        echo "   Checking node group status every 30 seconds..."
        
        for i in {1..10}; do
            echo "   Check $i/10:"
            
            NODE_GROUPS_CURRENT=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --output text --query 'nodegroups[]' 2>/dev/null)
            
            for nodegroup in $NODE_GROUPS_CURRENT; do
                STATUS=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $nodegroup --region $REGION --query 'nodegroup.status' --output text)
                DESIRED=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $nodegroup --region $REGION --query 'nodegroup.scalingConfig.desiredSize' --output text)
                echo "     $nodegroup: $STATUS (desired: $DESIRED)"
            done
            
            # Check if any nodes are ready
            READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
            echo "     Ready nodes: $READY_NODES"
            
            if [ "$READY_NODES" -gt "0" ]; then
                echo "   ✅ Nodes are ready!"
                break
            fi
            
            if [ $i -lt 10 ]; then
                echo "   ⏳ Waiting 30 seconds..."
                sleep 30
            fi
        done
    else
        echo "   No node groups to monitor"
    fi
    echo
}

# Function to verify cluster health
verify_cluster_health() {
    echo "5. Verifying cluster health:"
    
    echo "   Checking nodes:"
    kubectl get nodes -o wide 2>/dev/null || echo "   No nodes available yet"
    
    echo "   Checking system pods:"
    kubectl get pods -n kube-system | grep -E "(coredns|aws-node|kube-proxy)" || echo "   System pods not ready yet"
    
    echo "   Checking if pods can be scheduled:"
    PENDING_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
    echo "   Pending pods: $PENDING_PODS"
    
    if [ "$PENDING_PODS" -eq "0" ]; then
        echo "   ✅ All pods are scheduled!"
    else
        echo "   ⏳ Some pods are still pending (this is normal during node startup)"
    fi
    echo
}

# Main execution
main() {
    echo "Starting EKS node group recovery for cluster: $CLUSTER_NAME"
    echo "Region: $REGION"
    echo
    
    check_node_groups
    scale_existing_node_groups
    create_node_group
    monitor_node_groups
    verify_cluster_health
    
    echo "=== Recovery Complete ==="
    echo "Next steps:"
    echo "1. Wait for nodes to be fully ready (may take 5-10 minutes total)"
    echo "2. Check pod status: kubectl get pods --all-namespaces"
    echo "3. Check DIGIT services: kubectl get pods -n egov"
    echo "4. If pods are still pending, wait a few more minutes for nodes to initialize"
    echo
}

# Run the main function
main