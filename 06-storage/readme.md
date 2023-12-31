# Storage

Since the data of our auction service is very important, we want to save it to disk. In order to do that we can change our redis configuration to include `appendonly yes`. This way Redis stores every change to a local append only file.

Connect to the redis container and see what is stored in `/data`. Add some bids using the Auction frontend, how does the data in that folder change?

Now restart the redis instance by deleting the pod

`kubectl delete pods <redis-pod-name>`

Check the data in /data again. Open the Auction Webapp. What's the highest bid?

## 1. Create a Persistent Volume Claim

First we create a volume claim, so that we can mount it to redis afterwards:

### minikube
```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: redis-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

### AWS
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-data
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 1Gi
```

Get the information of the created volume:

`kubectl get persistentvolumeclaim`

## 2. Mount the volume

With our newly created volume, we are able to mount it to store our redis data. We can add this snippet to our redis-deployment:

```yaml
    volumeMounts:
        - name: redis-data-vol
          mountPath: /data/
volumes:
    - name: redis-data-vol
      persistentVolumeClaim:
        claimName: redis-data
```

Now delete the redis pod and wait for it to be restarted. What's the highest bid now?

