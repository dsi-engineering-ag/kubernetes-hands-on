#!/bin/bash
CLUSTER_NAME="eks-hands-on"
cd solution || exit

kubectl delete deployment --all -A
kubectl delete ingress --all -A
kubectl delete pvc --all -A
kubectl delete sc --all -A


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

aws efs delete-file-system --file-system-id $FILE_SYSTEM_ID
MOUNT_TARGET_GROUP_ID=$(aws ec2 create-security-group --group-name $MOUNT_TARGET_GROUP_NAME --description "$MOUNT_TARGET_GROUP_DESC" --vpc-id $VPC_ID | jq --raw-output '.GroupId')
aws ec2 delete-security-group --group-id $MOUNT_TARGET_GROUP_ID


eksctl delete nodegroup --cluster=$CLUSTER_NAME --name=spot-node-group-1
eksctl delete cluster --name $CLUSTER_NAME

aws iam delete-policy --policy-arn $(jq -r '.Policy.Arn' aws-loadbalancer-iam-policy.json)

aws iam delete-open-id-connect-provider --open-id-connect-provider-arn $(jq -r '.Statement[0].Principal.Federated' load-balancer-role-trust-policy.json)

cd ..



