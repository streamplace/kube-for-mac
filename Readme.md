
# kube-for-mac

Last night I got Kubernetes running on Docker for Mac.

I'm not sure if this is evil or not yet. Certainly both the Docker and Kubernetes teams tell you
not to do it. So. Use at your own risk. `¯\_(ツ)_/¯`

## Installing

I like to start with a Docker factory reset first. Because then you know where the button is when
this script totally hoses your Docker VM and you need to start over.

<img src="https://cloud.githubusercontent.com/assets/257909/23344812/dad13f48-fc37-11e6-9e4f-ab8358d4e3ae.png">

I also like to beef up Docker's resource allocations first if I'm planning on doing anything complicated with the cluster.

<img src="https://cloud.githubusercontent.com/assets/257909/23344830/1634e558-fc38-11e6-94b7-e9b15a699868.png">

Then:

```
docker run --privileged -v /:/rootfs -v /Users:/Users -d streamplace/kube-for-mac
```

Be aware that this will create ~15 Docker containers on your Docker for Mac. Because Kubernetes.

## Uninstalling

Reboot Docker for Mac. Then:

```
docker run --rm --privileged -v /:/rootfs streamplace/kube-for-mac stop
```

That should delete all the Kubernetes-related stuff from the VM, while leaving the Docker VM
intact.

## Now what?

Because the Kubernetes server takes over port 8080 on the Docker VM, we can't easily forward local
port 8080 to your local Kubernetes cluster, and we run on port 8888 instead. So you might wanna throw this in your `~/.kube/config`:

```
apiVersion: v1
clusters:
- cluster:
    server: http://localhost:8888
  name: kube-for-mac
contexts:
- context:
    cluster: kube-for-mac
    namespace: default
    user: kube-for-mac
  name: kube-for-mac
current-context: kube-for-mac
kind: Config
preferences: {}
users:
- name: kube-for-mac
```

## What is this `run-docker-kube-for-mac.sh` thingie?

It's a handy shell script that fires up the whole thing for you.

And it is designed to account for - er, um - "improvements" to Kubernetes.

Such as 1.6.3 that out-of-the-box guarantees breakage (if for nothing else the fact that API Server has a new default of etcd version 3 - while the out-of-the-box kubelet still builds etcd version 2).

First, let's start everything with the v1.6.3 hacks:
```
CloudraticSolutionsLLCs-MacBook-Pro:kube-for-mac l.abruce$ ./hacks/v1.6.3/run ./run-docker-kube-for-mac.sh start
Starting kube-for-mac...
docker run --privileged -v /:/rootfs -v /Users:/Users \
  --volume /Users/l.abruce/proj/docker/sab/kube-for-mac/hacks/v1.6.3:/etc/hacks-in:ro \
  -d --name run-docker-kube-for-mac-start \
  -e DOCKER_ARGS="--volume /etc/hacks/v1.6.3/kubelet/etc/kubernetes/manifests/master.json:/etc/kubernetes/manifests/master.json:ro" \
  -e K8S_VERSION=1.6.3 \
  -e KUBELET_ARGS="--cgroups-per-qos=false --enforce-node-allocatable=""" \
  -e K8S_HACKS="/etc/hacks-in/hacks.sh" \
  streamplace/kube-for-mac:latest
228415e9cfea0905d2d4ab497c57264ef0c25b7e2457ef7f5807add2e76b110b
Wait for start: .OK
Wait for server: ..OK
```

This starts all of the required containers. Let's take a look at what got created:
```
CloudraticSolutionsLLCs-MacBook-Pro:kube-for-mac l.abruce$ kubectl get ns
NAME          STATUS    AGE
default       Active    21s
kube-public   Active    20s
kube-system   Active    21s
CloudraticSolutionsLLCs-MacBook-Pro:kube-for-mac l.abruce$ kubectl --namespace=kube-system get pods
NAME                                    READY     STATUS    RESTARTS   AGE
k8s-master-127.0.0.1                    4/4       Running   1          26s
kube-dns-806549836-78b1t                3/3       Running   0          20s
kubernetes-dashboard-2917854236-bmrws   1/1       Running   0          21s
```

Let's run a simple container and verify that DNS works. (Which - just FYI - I cannot get to work with `kubeadm` on CentOS or Fedora. But does work here.)
```
CloudraticSolutionsLLCs-MacBook-Pro:kube-for-mac l.abruce$ kubectl run -i -t busybox --image=busybox --restart=Never
If you don't see a command prompt, try pressing enter.
/ # nslookup kubernetes
Server:    10.0.0.10
Address 1: 10.0.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes
Address 1: 10.0.0.1 kubernetes.default.svc.cluster.local
/ # exit
```

Take a quick peak at the pods:
```
CloudraticSolutionsLLCs-MacBook-Pro:kube-for-mac l.abruce$ kubectl get pods --show-all
NAME      READY     STATUS      RESTARTS   AGE
busybox   0/1       Completed   0          18s
```

Alright, I'm spent. Let's kill them all:
```
CloudraticSolutionsLLCs-MacBook-Pro:kube-for-mac l.abruce$ ./hacks/v1.6.3/run ./run-docker-kube-for-mac.sh stop
Stopping kube-for-mac...
docker run --privileged -v /:/rootfs -v /Users:/Users \
  --volume /Users/l.abruce/proj/docker/sab/kube-for-mac/hacks/v1.6.3:/etc/hacks-in:ro \
  -d --name run-docker-kube-for-mac-stop \
  -e K8S_VERSION=1.6.3 \
  -e K8S_HACKS="/etc/hacks-in/hacks.sh" \
  streamplace/kube-for-mac:latest stop
1948d282576b90379c2abf7568aa1a649b2b45821130090209067a0ee9698462
Wait for stop: ..........OK

>>>>>>>  Deleting Kubernetes cluster...
kubelet
k8s-proxy-1
k8s-proxy-2

>>>>>>>  Deleting all kubernetes containers...
k8s_busybox_busybox_default_b3b2e79c-3a35-11e7-869c-ba4b3ade41c6_0
k8s_POD_busybox_default_b3b2e79c-3a35-11e7-869c-ba4b3ade41c6_0
k8s_sidecar_kube-dns-806549836-78b1t_kube-system_8eda149b-3a35-11e7-869c-ba4b3ade41c6_0
k8s_dnsmasq_kube-dns-806549836-78b1t_kube-system_8eda149b-3a35-11e7-869c-ba4b3ade41c6_0
k8s_kubedns_kube-dns-806549836-78b1t_kube-system_8eda149b-3a35-11e7-869c-ba4b3ade41c6_0
k8s_POD_kube-dns-806549836-78b1t_kube-system_8eda149b-3a35-11e7-869c-ba4b3ade41c6_0
k8s_kubernetes-dashboard_kubernetes-dashboard-2917854236-bmrws_kube-system_8e283f9d-3a35-11e7-869c-ba4b3ade41c6_0
k8s_POD_kubernetes-dashboard-2917854236-bmrws_kube-system_8e283f9d-3a35-11e7-869c-ba4b3ade41c6_0
k8s_apiserver_k8s-master-127.0.0.1_kube-system_46406242b8e4a9b7dee0f580bce8311d_1
k8s_setup_k8s-master-127.0.0.1_kube-system_46406242b8e4a9b7dee0f580bce8311d_0
k8s_scheduler_k8s-master-127.0.0.1_kube-system_46406242b8e4a9b7dee0f580bce8311d_0
k8s_kube-addon-manager-data_kube-addon-manager-127.0.0.1_kube-system_6d93f1030e8e9e6e27f07f918bada68b_0
k8s_apiserver_k8s-master-127.0.0.1_kube-system_46406242b8e4a9b7dee0f580bce8311d_0
k8s_etcd_k8s-etcd-127.0.0.1_kube-system_ce41cb65bfba8d0e5f2575acaa3816ca_0
k8s_controller-manager_k8s-master-127.0.0.1_kube-system_46406242b8e4a9b7dee0f580bce8311d_0
k8s_kube-addon-manager_kube-addon-manager-127.0.0.1_kube-system_6d93f1030e8e9e6e27f07f918bada68b_0
k8s_kube-proxy_k8s-proxy-127.0.0.1_kube-system_d00ccc45519f37e0b496f8ba2ebc1354_0
k8s_POD_k8s-etcd-127.0.0.1_kube-system_ce41cb65bfba8d0e5f2575acaa3816ca_0
k8s_POD_kube-addon-manager-127.0.0.1_kube-system_6d93f1030e8e9e6e27f07f918bada68b_0
k8s_POD_k8s-master-127.0.0.1_kube-system_46406242b8e4a9b7dee0f580bce8311d_0
k8s_POD_k8s-proxy-127.0.0.1_kube-system_d00ccc45519f37e0b496f8ba2ebc1354_0

>>>>>>>  Deleting kube-for-mac startup container...
streamplace/kube-for-mac:latest
228415e9cfea

>>>>>>>  Removing all kubelet mounts

>>>>>>>  Removing /var/lib/kubelet

>>>>>>>  Executing hack: '/etc/hacks-in/hacks.sh'
Cleanup Docker Alpine folder...
Remove our specific hacks folder...
```

That is all.
