#!/bin/bash

CLUSTER_NAME="eks-hands-on"

# create cluster
# https://aws.amazon.com/tutorials/amazon-eks-with-spot-instances/
# eksctl create cluster --version=1.27 --name=$CLUSTER_NAME --nodes=2 --managed --region=eu-central-1 --node-type t2.medium --asg-access --with-oidc --dry-run > eks-cluster.yaml
eksctl create cluster -f eks-cluster.yaml
eksctl create nodegroup --cluster=$CLUSTER_NAME --region=eu-central-1 --managed --spot --name=spot-node-group-1 --instance-types=t2.large --nodes-min=1 --nodes-max=10 --nodes=10 --asg-access --alb-ingress-access
# aws autoscaling describe-auto-scaling-groups
# aws autoscaling update-auto-scaling-group --auto-scaling-group-name eks-ng-f6e5f35c-76c4faea-d968-c821-7c3a-6c30d0c6e80e --desired-capacity 2
# aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[].[AutoScalingGroupName, MinSize, MaxSize,DesiredCapacity]" --output table
mkdir solution
cd solution || exit

# install metric server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl get deployment metrics-server -n kube-system

# CloudWatch logs
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cloudwatch-namespace.yaml
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'
[[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'
[[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'
kubectl create configmap fluent-bit-cluster-info \
--from-literal=cluster.name=${CLUSTER_NAME} \
--from-literal=http.server=${FluentBitHttpServer} \
--from-literal=http.port=${FluentBitHttpPort} \
--from-literal=read.head=${FluentBitReadFromHead} \
--from-literal=read.tail=${FluentBitReadFromTail} \
--from-literal=logs.region=eu-central-1 -n amazon-cloudwatch
# curl -O https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit/fluent-bit.yaml
kubectl apply -f ../fluent-bit.yaml
kubectl get pods -n amazon-cloudwatch

# https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-metrics.html
CLUSTER_ROLE_ARN=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query "cluster.roleArn" --output text)
CLUSTER_ROLE_NAME=$(aws iam list-roles --query "Roles[?Arn  == '$CLUSTER_ROLE_ARN'].RoleName" --output text)
aws iam attach-role-policy --role-name "$CLUSTER_ROLE_NAME" --policy-arn "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"

NODEGROUP_ROLE_ARN=$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "spot-node-group-1" --query "nodegroup.nodeRole" --output text)
NODEGROUP_ROLE_NAME=$(aws iam list-roles --query "Roles[?Arn  == '$NODEGROUP_ROLE_ARN'].RoleName" --output text)
aws iam attach-role-policy --role-name "$NODEGROUP_ROLE_NAME" --policy-arn "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"

kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cwagent/cwagent-serviceaccount.yaml

# curl -O https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cwagent/cwagent-configmap.yaml
kubectl apply -f ../cwagent-configmap.yaml
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cwagent/cwagent-daemonset.yaml

## Install AWS Ingress Controller
# https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html

oidc_id=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)

curl -o alb_iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://alb_iam_policy.json > aws-loadbalancer-iam-policy.json

cat >load-balancer-role-trust-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::$(aws sts get-caller-identity --query "Account" --output text):oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/$oidc_id"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.eu-central-1.amazonaws.com/id/${oidc_id}:aud": "sts.amazonaws.com",
                    "oidc.eks.eu-central-1.amazonaws.com/id/${oidc_id}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
                }
            }
        }
    ]
}
EOF

aws iam create-role \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --assume-role-policy-document file://"load-balancer-role-trust-policy.json" > aws-loadbalancer-iam-role.json

aws iam attach-role-policy \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query "Account" --output text):policy/AWSLoadBalancerControllerIAMPolicy \
  --role-name AmazonEKSLoadBalancerControllerRole

cat >aws-load-balancer-controller-service-account.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: aws-load-balancer-controller
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::$(aws sts get-caller-identity --query "Account" --output text):role/AmazonEKSLoadBalancerControllerRole
EOF

kubectl apply -f aws-load-balancer-controller-service-account.yaml

eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::$(aws sts get-caller-identity --query "Account" --output text):policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

kubectl rollout status deployment aws-load-balancer-controller -n kube-system --timeout=120s

# Setup EFS Controller

curl -S https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/docs/iam-policy-example.json -o efs-iam-policy.json
awk '{gsub(/elasticfilesystem:CreateAccessPoint/, "elasticfilesystem:*"); print}' efs-iam-policy.json > fixed-efs-iam-policy.json
aws iam create-policy --policy-name EFSCSIControllerIAMPolicy --policy-document file://fixed-efs-iam-policy.json > created-efs-policy.json
eksctl create iamserviceaccount --cluster=$CLUSTER_NAME --region eu-central-1 --namespace=kube-system --name=efs-csi-controller-sa \
  --override-existing-serviceaccounts \
  --attach-policy-arn=arn:aws:iam::$(aws sts get-caller-identity --query "Account" --output text):policy/EFSCSIControllerIAMPolicy \
  --approve

helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver
helm repo update
helm upgrade -i aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
  --namespace kube-system \
  --set controller.serviceAccount.create=false \
  --set controller.serviceAccount.name=efs-csi-controller-sa

aws efs create-file-system > file-system.json
FILE_SYSTEM_ID=$(jq --raw-output '.FileSystemId' file-system.json)

VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.resourcesVpcConfig.vpcId" --output text)
CIDR_BLOCK=$(aws ec2 describe-vpcs --vpc-ids $VPC_ID --query "Vpcs[].CidrBlock" --output text)
MOUNT_TARGET_GROUP_NAME="eks-efs-group"
MOUNT_TARGET_GROUP_DESC="NFS access to EFS from EKS worker nodes"
aws ec2 create-security-group --group-name $MOUNT_TARGET_GROUP_NAME --description "$MOUNT_TARGET_GROUP_DESC" --vpc-id $VPC_ID > security-group-$MOUNT_TARGET_GROUP_NAME.json
MOUNT_TARGET_GROUP_ID=$(jq --raw-output '.GroupId' security-group-$MOUNT_TARGET_GROUP_NAME.json)
aws ec2 authorize-security-group-ingress --group-id $MOUNT_TARGET_GROUP_ID --protocol tcp --port 2049 --cidr $CIDR_BLOCK > security-group-rule-$MOUNT_TARGET_GROUP_ID.json
subnets=($(aws ec2 describe-subnets | jq --raw-output '.Subnets[].SubnetId'))
for subnet in ${subnets[@]}
do
    echo "creating mount target in " $subnet
    aws efs create-mount-target --file-system-id $FILE_SYSTEM_ID --subnet-id $subnet --security-groups $MOUNT_TARGET_GROUP_ID > mount-$subnet.json
done

aws efs describe-mount-targets --file-system-id $FILE_SYSTEM_ID | jq --raw-output '.MountTargets[].LifeCycleState'


cat >efs-sc.yaml <<EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: $FILE_SYSTEM_ID
  directoryPerms: "700"
EOF
kubectl apply -f efs-sc.yaml

# calico
# https://docs.aws.amazon.com/eks/latest/userguide/calico.html
cat << EOF > append-clusterrole.yaml
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - patch
EOF
kubectl apply -f <(cat <(kubectl get clusterrole aws-node -o yaml) append-clusterrole.yaml)
kubectl set env daemonset aws-node -n kube-system ANNOTATE_POD_IP=true

# https://docs.tigera.io/calico/3.25/getting-started/kubernetes/helm#install-calico
helm repo add projectcalico https://docs.tigera.io/calico/charts
echo '{ installation: {kubernetesProvider: EKS }}' > calico-values.yaml
kubectl create namespace tigera-operator
helm install calico projectcalico/tigera-operator --version v3.25.1 -f calico-values.yaml --namespace tigera-operator

cd ..
