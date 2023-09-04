kubectl get deployments --all-namespaces -o json | jq -r '.items[] | select(.spec.template.spec.containers[].resources.limits == null) | .metadata.namespace + "/" + .metadata.name'
