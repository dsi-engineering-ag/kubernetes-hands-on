#!/bin/bash
CLUSTER_NAME="eks-hands-on"
cd solution || exit


kubectl delete ingress --all -A

kubectl get deployments --all-namespaces -o=jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' | while read -r namespace deployment; do
    pvc_names=$(kubectl get deployment -n $namespace $deployment -o=jsonpath='{.spec.template.spec.volumes[*].persistentVolumeClaim.claimName}')
    if [ -n "$pvc_names" ]; then
        kubectl delete deployment -n $namespace $deployment
        kubectl delete pvc -n $namespace $pvc_names
    fi
done

kubectl delete sc --all -A
kubectl delete hpa --all -A
kubectl delete deployment --all -A

# EFS cleanup
kubectl delete -f efs-sc.yaml
eksctl delete iamserviceaccount --cluster=$CLUSTER_NAME --region eu-central-1 --namespace=kube-system --name=efs-csi-controller-sa
helm delete aws-efs-csi-driver -n kube-system

FILE_SYSTEM_ID=$(jq --raw-output '.FileSystemId' file-system.json)
targets=$(aws efs describe-mount-targets --file-system-id $FILE_SYSTEM_ID | jq --raw-output '.MountTargets[].MountTargetId')
for target in ${targets[@]}
do
    echo "deleting mount target " $target
    aws efs delete-mount-target --mount-target-id $target
done

MOUNT_TARGET_GROUP_NAME="eks-efs-group"
MOUNT_TARGET_GROUP_ID=$(jq --raw-output '.GroupId' security-group-$MOUNT_TARGET_GROUP_NAME.json)
aws ec2 delete-security-group --group-id $MOUNT_TARGET_GROUP_ID

aws efs delete-file-system --file-system-id $FILE_SYSTEM_ID

eksctl delete nodegroup --cluster=$CLUSTER_NAME --name=spot-node-group-1
eksctl delete cluster --name $CLUSTER_NAME

aws iam delete-policy --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query "Account" --output text):policy/EFSCSIControllerIAMPolicy
aws iam delete-policy --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query "Account" --output text):policy/AWSLoadBalancerControllerIAMPolicy


aws iam delete-open-id-connect-provider --open-id-connect-provider-arn $(jq -r '.Statement[0].Principal.Federated' load-balancer-role-trust-policy.json)

cd ..



