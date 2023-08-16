# Networking: Ingress

In all previous excercies we accessed our cluster from within the cluster. To receive traffic from outside, we somehow need to get it in. Kubernetes supports different [ingress controllers](https://kubernetes.io/docs/concepts/services-networking/ingress/#ingress-controllers).

## minikube
We use the Nginx Ingress Controller. It's installation is easy when using minikube. But before we installed it, let's check what happens if we call our minikube node:

Get the IP:

`minikube ip`

and then try to access that ip from your machine:

`curl -i <ip>`

Now lets install our ingress controller:

`minikube addons enable ingress`

This creates new pods. Wait until alle pods are running.

`kubectl get pods --all-namespaces`

Access the node again from your machine:

`curl -i <ip>`

- What changed?
- What was deployed on your cluster? Check all running pods in your cluster: `kubectl get --all-namespaces pods`
- Where does the answer for your HTTP GET come from?

## AWS
We are using the AWS Load Balancer Controller. The controller is already installed. 
You can find them using the following command:
`kubectl get pods -n kube-system`

## 1. Create an ingress resource

Let's add a route to our auction backend:

### minikube
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: auction-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: auction
                port:
                  number: 80
```

### AWS
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: auction-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: instance
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: auction
                port:
                  number: 80

```
No if you connect with your browser to the minikube ip you should see the auction app again:

![Webapp](webapp.png "Auction App")

- What happens if you configured a wrong backend?
- Can you access the ingress ressource from outside of the cluster?
- Can you access the ingress ressource from inside the cluster?
- Try to draw a short diagram showing all involved components
