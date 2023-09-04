# Helm

## 1. Install Redis Cluster

We will use helm to install another redis service. We'd like to have a redis cluster with multiple read-replicas.

```sh
helm install --set auth.enabled=false --set global.storageClass=efs-sc my-cluster oci://registry-1.docker.io/bitnamicharts/redis --version 17.16.0
```

Check what was deployed by using `kubectl get pods`, `kubectl get statefulsets`, `kubectl get pvc` and `kubectl get service`

## 2. Switch our application to new cluster

Update your web deployment to point to your newly created cluster master.

- Test the application. Everything working as expected?

## 3. Upgrade cluster

```
helm upgrade my-cluster oci://registry-1.docker.io/bitnamicharts/redis
```

Verify your deployment. Did the new chart version deploy?


### Bonus Exercise - Extract configuration to file

Setting parameters while executing the helm command does not scale. Best practice is to store configuration values in a file. This way, it can be shared and put under version control.

Extract our parameters to a helm configuration file called `redis-values.yaml`. Use it to upgrade your release.

### Bonus Exercise - Configure number of slaves

You can change an existing helm release by calling `helm upgrade -f redis-values.yaml <release-name> <chart>`. You can specify changed configuration values as well. Try to start more read replicas. Consult the documentation of the helm chart and upgrade your release to more read replicas: https://github.com/bitnami/charts/tree/main/bitnami/redis

### Bonus Exercise - Configure Link to headless service

- Does the application still work?
- What would you need to change to fix it?

