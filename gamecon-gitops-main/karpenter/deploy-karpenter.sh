#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="andi-eks-cluster"
KARPENTER_NAMESPACE="karpenter"
AWS_ACCOUNT_ID="793786247026"

echo -e "${GREEN}Starting Karpenter deployment script${NC}"

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}kubectl is not installed or not in PATH${NC}"
        exit 1
    fi
    echo -e "${GREEN}kubectl is available${NC}"
}

# Function to check if helm is available
check_helm() {
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}helm is not installed or not in PATH${NC}"
        exit 1
    fi
    echo -e "${GREEN}helm is available${NC}"
}

# Function to check cluster connectivity
check_cluster() {
    echo -e "${YELLOW}Checking cluster connectivity...${NC}"
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Cannot connect to Kubernetes cluster${NC}"
        exit 1
    fi
    echo -e "${GREEN}Connected to cluster: $(kubectl config current-context)${NC}"
}

# Function to apply aws-auth ConfigMap
apply_aws_auth() {
    echo -e "${YELLOW}Applying aws-auth ConfigMap...${NC}"
    
    kubectl apply -f aws-auth-fix.yaml
    
    echo -e "${GREEN}aws-auth ConfigMap applied successfully${NC}"
}

# Function to install Karpenter using Helm
install_karpenter() {
    echo -e "${YELLOW}Installing Karpenter with Helm...${NC}"
    
    # Get cluster endpoint
    CLUSTER_ENDPOINT=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query 'cluster.endpoint' --output text)
    echo -e "${BLUE}Cluster endpoint: ${CLUSTER_ENDPOINT}${NC}"
    
    # Install Karpenter
    helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
      --version "1.5.0" \
      --namespace ${KARPENTER_NAMESPACE} \
      --create-namespace \
      --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-karpenter-role" \
      --set "settings.clusterName=${CLUSTER_NAME}" \
      --set "settings.clusterEndpoint=${CLUSTER_ENDPOINT}" \
      --set installCRDs=true \
      --wait
    
    echo -e "${GREEN}Karpenter installed successfully${NC}"
}

# Function to wait for Karpenter to be ready
wait_for_karpenter() {
    echo -e "${YELLOW}Waiting for Karpenter deployment to be ready...${NC}"
    
    kubectl wait --for=condition=available --timeout=300s deployment/karpenter -n ${KARPENTER_NAMESPACE}
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Karpenter deployment is ready${NC}"
    else
        echo -e "${RED}Timeout waiting for Karpenter deployment${NC}"
        exit 1
    fi
}

# Function to apply Karpenter configuration
apply_karpenter_config() {
    echo -e "${YELLOW}Applying Karpenter NodePool and EC2NodeClass...${NC}"
    
    kubectl apply -f karpenter-config.yaml
    
    echo -e "${GREEN}Karpenter configuration applied successfully${NC}"
}

# Function to verify Karpenter status
verify_karpenter() {
    echo -e "${YELLOW}Verifying Karpenter status...${NC}"
    
    echo "Karpenter pods:"
    kubectl get pods -n ${KARPENTER_NAMESPACE}
    
    echo -e "\nNodePools:"
    kubectl get nodepools
    
    echo -e "\nEC2NodeClasses:"
    kubectl get ec2nodeclasses
    
    echo -e "\nCurrent nodes:"
    kubectl get nodes
    
    echo -e "${GREEN}Karpenter verification complete${NC}"
}

# Function to show helpful commands
show_helpful_commands() {
    echo -e "\n${BLUE}Useful commands for monitoring Karpenter:${NC}"
    echo -e "${YELLOW}  kubectl get nodes -w${NC}                               # Watch nodes"
    echo -e "${YELLOW}  kubectl get nodeclaims -w${NC}                          # Watch Karpenter provision nodes"
    echo -e "${YELLOW}  kubectl logs -n karpenter deployment/karpenter -f${NC}  # Karpenter logs"
    echo -e "${YELLOW}  kubectl get events --sort-by='.lastTimestamp'${NC}      # Recent events"
}

# Main execution
main() {
    echo -e "${GREEN}Starting Karpenter deployment process...${NC}\n"
    
    check_kubectl
    check_helm
    check_cluster
    apply_aws_auth
    install_karpenter
    wait_for_karpenter
    apply_karpenter_config
    verify_karpenter
    show_helpful_commands
    
    echo -e "\n${GREEN}Karpenter deployment completed successfully!${NC}"
    echo -e "${YELLOW}Karpenter is now ready to provision nodes for your cluster${NC}"
}

# Execute main function
main "$@"