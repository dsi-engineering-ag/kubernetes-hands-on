kubectl apply -f cwagent-configmap.yaml
kubectl rollout restart daemonset -n amazon-cloudwatch cloudwatch-agent
