# Autoscaling

This exercise is for AWS only.

In the previous exercise, we've seen that our pods are struggling with the load.
To solve that issue, we can scale our deployment based on the cpu usage. 
Before we get started, we should create another graph which shows the number of pods running for a service.

Use the "service_number_of_running_pods" metric for that.

Also make sure your resources of your `web` deployment is set to these values:
```yaml
resources:
  requests:
    memory: "32Mi"
    cpu: "100m"
  limits:
    memory: "64Mi"
    cpu: "100m"
```

Make sure you have stopped the load generator from our previous exercise and apply the following `Horizontal Pod Autoscaler`.
Use your dashboards from our previous exercise to monitor our number of pods. 

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web
spec:
  maxReplicas: 4
  minReplicas: 1
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 30
  metrics:
    - resource:
        name: cpu
        target:
          averageUtilization: 70
          type: Utilization
      type: Resource
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web
```

- Did your pod count go down? Use `kubectl describe hpa web` to examine the events.
- Why did it take so long to scale down the replica size?


Like in our previous exercise, we can generate some load again using this command:
```bash
kubectl run -i --tty load-generator --rm --image=jordi/ab --restart=Never -- -v 2 -n 10000 -c 10 -s 120 <yourIngressUrl>/high-cpu
```

- When and how is the replica size being scaled up?
- Bonus exercise: Make your pods scale from 1 to 4 within 10 seconds
