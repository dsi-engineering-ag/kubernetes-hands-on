# Monitoring

This exercise is for AWS only.

## Logging

Let's use a bastion pod to simulate a bad request, which will cause an unexpected server error. Please replace `<yourIngressUrl>` with your ingress URL.

```bash
kubectl run my-shell --rm -it --image jonlabelle/network-tools -- bash -c "while sleep 5; do curl -v <yourIngressUrl> --data 'bid=error'; done"
```

- Can you see these errors using CloudWatch?
  Visit https://eu-central-1.console.aws.amazon.com/cloudwatch/home?region=eu-central-1#logsV2:logs-insights
  Use `Logs Insight` to find your server errors. Don't forget to add a filter for your Kubernetes namespace:
  `| filter kubernetes.namespace_name = '<yourNamespace>'`

- How are the logs being sent to CloudWatch?
- What is the issue with the current logs? How could you solve that issue?

## ELB Metrics

Let's use the ELB Metrics to create a graph where we can track all requests by HTTP status code.

Visit https://eu-central-1.console.aws.amazon.com/cloudwatch/home?region=eu-central-1#metricsV2?graph=~()

Let's use the "ApplicationELB" "per AppELB" metrics to create a graph for the "RequestCount" of your application. In the "Graphed metrics" tab, you can modify your graph to use the "Sum" statistic and set your period to 1 minute.

Here is the documentation of CloudWatch metrics for your Classic Load Balancer:
https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-cloudwatch-metrics.html

Use the "Source" tab to add graphs for all `HTTPCode` metrics.

You should be able to see some requests and the unexpected server errors. Create and add this graph to your dashboard. Name your dashboard after your namespace.

- How are the metrics being sent to AWS CloudWatch?
- How often are they sent?

## Container Insights Metrics

Let's increase the load! With the simple ELB Monitoring, we should see issues when they arise. We will use a special endpoint to simulate a CPU-intensive task.

```bash
kubectl run -i --tty load-generator --rm --image=jordi/ab --restart=Never -- -v 2 -n 10000 -c 10 -s 120 <yourIngressUrl>/high-cpu
```

After a minute, you should see some errors. Let's create another graph to monitor our "web" pod using the container insights metrics. Create a graph with two metrics: CPU and memory usage relative to its limit.

You can find some documentation about the available metrics here:
https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-metrics-EKS.html

When you are finished, add this graph to your dashboard as well.

- How are the metrics being sent to AWS CloudWatch?
- How often are metrics being sent? Why not send them more often?

Please stop the load-generator before moving to the next exercise.
