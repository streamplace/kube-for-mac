
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

And it is designed to account for the ever-evolving nature of Kubernetes.

Such as 1.7.0 that no longer creates any of the manifests / addons that 1.6.x and prior versions did.

First, get a watcher up and running in another window:
```
watch -n 4 -d kubectl get all --all-namespaces -o wide
```

There will be no output until we start a Kubernetes cluster. So let's do that now with the v1.7.0 hacks:
```
CloudraticSolutionsLLCs-MacBook-Pro:kube-for-mac l.abruce$ ./hacks/v1.7.0/run ./run-docker-kube-for-mac.sh start
Starting kube-for-mac...
docker run --privileged -v /:/rootfs -v /Users:/Users --net=host \
  --volume /Users/l.abruce/proj/git/github.com/andybrucenet/kube-for-mac/hacks/v1.7.0:/etc/hacks-in:ro \
  -d --name docker-kube-for-mac-start \
  -e DOCKER_ARGS="--volume /etc/hacks/v1.7.0/kubelet/etc/kubernetes/manifests:/etc/kubernetes/manifests:ro" \
  -e K8S_VERSION=1.7.0 \
  -e KUBELET_ARGS="--cgroups-per-qos=false --enforce-node-allocatable='' --cpu-cfs-quota=false" \
  -e K8S_HACKS="/etc/hacks-in/hacks.sh" \
  streamplace/kube-for-mac:latest
9f8d1e5d3a28993785dba913da00387e32cb7cab3424ae3799c880336801f51f
Wait for start: ..OK
Wait for server: ..OK
```

This starts the basic set of required containers. Wait a couple of minutes and take a look at what got created:
```
CloudraticSolutionsLLCs-MacBook-Pro:kube-for-mac l.abruce$ kubectl get ns
NAME          STATUS    AGE
default       Active    1m
kube-public   Active    1m
kube-system   Active    1m
CloudraticSolutionsLLCs-MacBook-Pro:kube-for-mac l.abruce$ kubectl --namespace=kube-system get pods
NAME                           READY     STATUS    RESTARTS   AGE
k8s-etcd-127.0.0.1             1/1       Running   0          17s
k8s-master-127.0.0.1           3/3       Running   0          13s
k8s-proxy-127.0.0.1            1/1       Running   0          21s
kube-addon-manager-127.0.0.1   1/1       Running   0          27s
```

*Whoa* - the above doesn't show any DNS or Dashboard. What the fudge?
With K8s v1.7.0, things don't get auto-created like they used to. So we have an additional task to run:
```
CloudraticSolutionsLLCs-MacBook-Pro:kube-for-mac l.abruce$ ./hacks/v1.7.0/run ./run-docker-kube-for-mac.sh custom source /etc/hacks-in/hacks.sh DEPLOY-ADDONS
Running custom kube-for-mac...
docker run --rm --privileged -v /:/rootfs -v /Users:/Users --net=host \
  --volume /Users/l.abruce/proj/git/github.com/andybrucenet/kube-for-mac/hacks/v1.7.0:/etc/hacks-in:ro \
  -d --name docker-kube-for-mac-custom \
  -e DOCKER_ARGS="--volume /etc/hacks/v1.7.0/kubelet/etc/kubernetes/manifests:/etc/kubernetes/manifests:ro" \
  -e K8S_VERSION=1.7.0 \
  -e KUBELET_ARGS="--cgroups-per-qos=false --enforce-node-allocatable='' --cpu-cfs-quota=false" \
  -e K8S_HACKS="/etc/hacks-in/hacks.sh" \
  streamplace/kube-for-mac:latest custom \
  source /etc/hacks-in/hacks.sh DEPLOY-ADDONS
1f11281e3c21965ecf4cac7e6ec03d5a7f84460031361503bab49cf5945b6a4f
```

DNS and the Dashboard will take a few minutes to initialize. You can see the progress by watching the Docker logs:
```
CloudraticSolutionsLLCs-MacBook-Pro:kube-for-mac l.abruce$ docker logs -f docker-kube-for-mac-custom
Wait for kube-addon-manager...
OK
Sleeping for 120 seconds...
Deploy DNS...
Wait: ...........OK
Sleeping for 90 seconds...
Deploy Dashboard: OK
```

And now we have everything we need :)
```
CloudraticSolutionsLLCs-MacBook-Pro:kube-for-mac l.abruce$ kubectl --namespace=kube-system get pods
NAME                                    READY     STATUS    RESTARTS   AGE
k8s-etcd-127.0.0.1                      1/1       Running   0          6m
k8s-master-127.0.0.1                    3/3       Running   0          6m
k8s-proxy-127.0.0.1                     1/1       Running   0          6m
kube-addon-manager-127.0.0.1            1/1       Running   0          6m
kube-dns-1994753994-js1bx               3/3       Running   0          2m
kubernetes-dashboard-2037206258-m8gvj   1/1       Running   0          4s
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

Kill that pod:
```
CloudraticSolutionsLLCs-MacBook-Pro:kube-for-mac l.abruce$ kubectl delete po/busybox
pod "busybox" deleted
CloudraticSolutionsLLCs-MacBook-Pro:kube-for-mac l.abruce$ kubectl get pods --show-all
No resources found.
```

Alright, I'm spent. Let's kill them all:
```
CloudraticSolutionsLLCs-MacBook-Pro:kube-for-mac l.abruce$ ./hacks/v1.7.0/run ./run-docker-kube-for-mac.sh stop
Stopping kube-for-mac...
docker run --privileged -v /:/rootfs -v /Users:/Users --net=host \
  --volume /Users/l.abruce/proj/git/github.com/andybrucenet/kube-for-mac/hacks/v1.7.0:/etc/hacks-in:ro \
  -d --name docker-kube-for-mac-stop \
  -e DOCKER_ARGS="--volume /etc/hacks/v1.7.0/kubelet/etc/kubernetes/manifests:/etc/kubernetes/manifests:ro" \
  -e K8S_VERSION=1.7.0 \
  -e KUBELET_ARGS="--cgroups-per-qos=false --enforce-node-allocatable='' --cpu-cfs-quota=false" \
  -e K8S_HACKS="/etc/hacks-in/hacks.sh" \
  streamplace/kube-for-mac:latest stop
b5f15cd366d56b5f236a5124a145bb789a9fb5d4fac78c4168d420d508026e5c
Wait for stop: ......OK

>>>>>>>  Deleting Kubernetes cluster...
kubelet
k8s-proxy-1
k8s-proxy-2

>>>>>>>  Deleting all kubernetes containers...
k8s_busybox_busybox_default_062a5ef9-61a5-11e7-bfa3-b6f744b1340b_0
k8s_POD_busybox_default_062a5ef9-61a5-11e7-bfa3-b6f744b1340b_0
k8s_kubernetes-dashboard_kubernetes-dashboard-2037206258-m8gvj_kube-system_ea92787a-61a4-11e7-bfa3-b6f744b1340b_0
k8s_POD_kubernetes-dashboard-2037206258-m8gvj_kube-system_ea92787a-61a4-11e7-bfa3-b6f744b1340b_0
k8s_sidecar_kube-dns-1994753994-js1bx_kube-system_a35054fb-61a4-11e7-bfa3-b6f744b1340b_0
k8s_dnsmasq_kube-dns-1994753994-js1bx_kube-system_a35054fb-61a4-11e7-bfa3-b6f744b1340b_0
k8s_kubedns_kube-dns-1994753994-js1bx_kube-system_a35054fb-61a4-11e7-bfa3-b6f744b1340b_0
k8s_POD_kube-dns-1994753994-js1bx_kube-system_a35054fb-61a4-11e7-bfa3-b6f744b1340b_0
k8s_scheduler_k8s-master-127.0.0.1_kube-system_2067adabaa6980daef0907659b4a9544_0
k8s_apiserver_k8s-master-127.0.0.1_kube-system_2067adabaa6980daef0907659b4a9544_0
k8s_controller-manager_k8s-master-127.0.0.1_kube-system_2067adabaa6980daef0907659b4a9544_0
k8s_etcd_k8s-etcd-127.0.0.1_kube-system_bd1728a15ee1a9086d495f51c96057ca_0
k8s_kube-addon-manager_kube-addon-manager-127.0.0.1_kube-system_4c08b13eef6cddbcdd31605f3d9b08c6_0
k8s_kube-proxy_k8s-proxy-127.0.0.1_kube-system_93847eaf8fd3e196f07d899037b1b143_0
k8s_POD_k8s-master-127.0.0.1_kube-system_2067adabaa6980daef0907659b4a9544_0
k8s_POD_k8s-etcd-127.0.0.1_kube-system_bd1728a15ee1a9086d495f51c96057ca_0
k8s_POD_kube-addon-manager-127.0.0.1_kube-system_4c08b13eef6cddbcdd31605f3d9b08c6_0
k8s_POD_k8s-proxy-127.0.0.1_kube-system_93847eaf8fd3e196f07d899037b1b143_0

>>>>>>>  Deleting kube-for-mac startup container...
/docker-kube-for-mac-start
9f8d1e5d3a28

>>>>>>>  Removing all kubelet mounts (account for ordering)
Removing mount: /var/lib/kubelet/pods/ea92787a-61a4-11e7-bfa3-b6f744b1340b/volumes/kubernetes.io~secret/default-token-91ng7
Removing mount: /var/lib/kubelet/pods/a35054fb-61a4-11e7-bfa3-b6f744b1340b/volumes/kubernetes.io~secret/kube-dns-token-9l4mq
Removing mount: /var/lib/kubelet

>>>>>>>  Removing /var/lib/kubelet

>>>>>>>  Executing hack: '/etc/hacks-in/hacks.sh'
Cleanup Docker Alpine folder...
Remove our specific hacks folder...
```

Your Docker for Mac is now back to its original state. You can create another K8s cluster, or do any other work you wish.

That is all.

