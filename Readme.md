# DEPRECATED

[Docker does this now](https://blog.docker.com/2018/01/docker-mac-kubernetes/). So... use that.

Leaving everything else here for historical purposes.

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

## What are these `lcl-k8s4m.sh` and `run-docker-kube-for-mac.sh` thingies?

They are handy shell scripts to fire up K8s cluster from scratch, designed to account for the ever-evolving nature of Kubernetes. (Such as 1.7.0 that no longer creates any of the manifests / addons that 1.6.x and prior versions did.)

First, get a watcher up and running in a second window:
```
watch -n 4 -d kubectl get all --all-namespaces -o wide
```

In your first window, we want to start Kubernetes. You can use either of the two scripts above, but generally the `lcl-k8s4m.sh` script is simpler. It defaults to the latest supported Kubernetes version (v1.7.3 as of this writing).
```
./lcl-k8s4m.sh start
```

That starts the whole cluster from scratch. You can watch the progress by switching to your second window and looking at Let's see a typical run:
```
MacBook-Pro:kube-for-mac l.abruce$ ./lcl-k8s4m.sh start
Starting kube-for-mac...
docker run --privileged -v /:/rootfs -v /Users:/Users --net=host \
  --volume /Users/l.abruce/proj/git/src/github.com/andybrucenet/kube-for-mac/hacks/v1.7.3:/etc/hacks-in:ro \
  -d --name docker-kube-for-mac-start \
  -e DOCKER_ARGS="--volume /etc/hacks/v1.7.3/kubelet/etc/kubernetes/manifests:/etc/kubernetes/manifests:ro --volume /Users:/Users:rw" \
  -e K8S_VERSION=1.7.3 \
  -e KUBELET_ARGS="--cgroups-per-qos=false --enforce-node-allocatable='' --cpu-cfs-quota=false" \
  -e K8S_HACKS="/etc/hacks-in/hacks.sh" \
  -e K8S_DEBUG="1" \
  streamplace/kube-for-mac:latest
11caf3a986aad8020121d1175f18d934253cc0b5b8bc1273f2af790ef3180960
Wait for start: .OK
Wait for server: ..OK


Wait for k8s controllers: .................OK
Deploy DNS:

Running custom kube-for-mac...
docker run --rm --privileged -v /:/rootfs -v /Users:/Users --net=host \
  --volume /Users/l.abruce/proj/git/src/github.com/andybrucenet/kube-for-mac/hacks/v1.7.3:/etc/hacks-in:ro \
  -d --name docker-kube-for-mac-custom \
  -e DOCKER_ARGS="--volume /etc/hacks/v1.7.3/kubelet/etc/kubernetes/manifests:/etc/kubernetes/manifests:ro --volume /Users:/Users:rw" \
  -e K8S_VERSION=1.7.3 \
  -e KUBELET_ARGS="--cgroups-per-qos=false --enforce-node-allocatable='' --cpu-cfs-quota=false" \
  -e K8S_HACKS="/etc/hacks-in/hacks.sh" \
  -e K8S_DEBUG="1" \
  streamplace/kube-for-mac:latest custom \
  source /etc/hacks-in/hacks.sh DEPLOY-DNS
3321aa3cded16fc29c7cde5df01a7f4e419f160ce7f20b1803e11d162b7068bc
..........OK
Deploy Dashboard:

Running custom kube-for-mac...
docker run --rm --privileged -v /:/rootfs -v /Users:/Users --net=host \
  --volume /Users/l.abruce/proj/git/src/github.com/andybrucenet/kube-for-mac/hacks/v1.7.3:/etc/hacks-in:ro \
  -d --name docker-kube-for-mac-custom \
  -e DOCKER_ARGS="--volume /etc/hacks/v1.7.3/kubelet/etc/kubernetes/manifests:/etc/kubernetes/manifests:ro --volume /Users:/Users:rw" \
  -e K8S_VERSION=1.7.3 \
  -e KUBELET_ARGS="--cgroups-per-qos=false --enforce-node-allocatable='' --cpu-cfs-quota=false" \
  -e K8S_HACKS="/etc/hacks-in/hacks.sh" \
  -e K8S_DEBUG="1" \
  streamplace/kube-for-mac:latest custom \
  source /etc/hacks-in/hacks.sh DEPLOY-DASHBOARD
647de4a30318877ac123b92c4de1a56390f110566899581865f89694bfa49420
.........OK
$HELM_HOME has been configured at /Users/l.abruce/.helm.

Tiller (the helm server side component) has been installed into your Kubernetes Cluster.
Happy Helming!
Wait for helm tiller: ...OK
```

### That's too much output! And what is that `helm` thing?

So there are several steps to get Kubernetes working with the v1.7.x family:

* Start `kubectl` - this is the main workhorse, which spawns the API Server, ETCD Server, Scheduler..these are all the "k8s controllers" mentioned above.
* Deploy DNS / Dashboard - Once the Kubernetes controller servers are run, we deploy these "extra" elements that make for a successful Kubernetes install. As of v1.7.x, they aren't installed automatically by the `kubectl` deployment, so we run them manually.
* Deploy `helm` - Helm (https://github.com/kubernetes/helm) is a tool for managing Kubernetes by using "charts". If you have `helm` package available on your client, we will deploy it automatically to the new Kubernetes cluster. (If you do *not* have `helm` package, no worries - we just won't deploy it.) In a related project, I use `helm` to install OpenStack via containers on my local kube-for-mac!

As for the verbosity, if you would like more be sure to set the `DOCKER_KUBE_FOR_MAC_K8S_DEBUG` environment variable and we can give you more output :)

### So what does it look like when I'm done?

First, you can check out the results of your `watch ...` command above. Here's the list of deployed elements (took just a few minutes from zero-to-hero):
```
MacBook-Pro:poc l.abruce$ kubectl get all --all-namespaces
NAMESPACE     NAME                                       READY     STATUS    RESTARTS   AGE
kube-system   po/k8s-etcd-127.0.0.1                      1/1       Running   0          15m
kube-system   po/k8s-master-127.0.0.1                    3/3       Running   0          15m
kube-system   po/k8s-proxy-127.0.0.1                     1/1       Running   0          15m
kube-system   po/kube-addon-manager-127.0.0.1            1/1       Running   0          15m
kube-system   po/kube-dns-1994753994-gdjx1               3/3       Running   0          14m
kube-system   po/kubernetes-dashboard-4062213060-v5rtl   1/1       Running   0          13m
kube-system   po/tiller-deploy-3360264398-kkdxt          1/1       Running   0          13m

NAMESPACE     NAME                       CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
default       svc/kubernetes             10.0.0.1     <none>        443/TCP         16m
kube-system   svc/kube-dns               10.0.0.10    <none>        53/UDP,53/TCP   16m
kube-system   svc/kubernetes-dashboard   10.0.0.81    <none>        80/TCP          16m
kube-system   svc/tiller-deploy          10.0.0.55    <none>        44134/TCP       13m

NAMESPACE     NAME                          DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kube-system   deploy/kube-dns               1         1         1            1           14m
kube-system   deploy/kubernetes-dashboard   1         1         1            1           13m
kube-system   deploy/tiller-deploy          1         1         1            1           13m

NAMESPACE     NAME                                 DESIRED   CURRENT   READY     AGE
kube-system   rs/kube-dns-1994753994               1         1         1         14m
kube-system   rs/kubernetes-dashboard-4062213060   1         1         1         13m
kube-system   rs/tiller-deploy-3360264398          1         1         1         13m
```

Assuming you understand the intricacies of `kubeconfig` (https://kubernetes.io/docs/tasks/access-application-cluster/authenticate-across-clusters-kubeconfig/), you can setup your calls to default to your shiny new local cluster like we did above.

### Does this actually run anything?

Let's run a simple container and verify that DNS works:
```
MacBook-Pro:poc l.abruce$ kubectl run --rm -i -t busybox --image=busybox --restart=Never
If you don't see a command prompt, try pressing enter.
/ # nslookup kubernetes
Server:    10.0.0.10
Address 1: 10.0.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes
Address 1: 10.0.0.1 kubernetes.default.svc.cluster.local
/ # ping -c 1 google.com
PING google.com (216.239.38.120): 56 data bytes
64 bytes from 216.239.38.120: seq=0 ttl=37 time=0.612 ms

--- google.com ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
round-trip min/avg/max = 0.612/0.612/0.612 ms
/ # exit
```

You should see that the pod was killed automatically (use of the `--rm` flag to `kubectl run`).

### How do I kill the cluster using the script?

Alright, I'm spent. Let's kill everything:
```
MacBook-Pro:kube-for-mac l.abruce$ ./lcl-k8s4m.sh stop
Stopping kube-for-mac...
docker run --privileged -v /:/rootfs -v /Users:/Users --net=host \
  --volume /Users/l.abruce/proj/git/src/github.com/andybrucenet/kube-for-mac/hacks/v1.7.3:/etc/hacks-in:ro \
  -d --name docker-kube-for-mac-stop \
  -e DOCKER_ARGS="--volume /etc/hacks/v1.7.3/kubelet/etc/kubernetes/manifests:/etc/kubernetes/manifests:ro --volume /Users:/Users:rw" \
  -e K8S_VERSION=1.7.3 \
  -e KUBELET_ARGS="--cgroups-per-qos=false --enforce-node-allocatable='' --cpu-cfs-quota=false" \
  -e K8S_HACKS="/etc/hacks-in/hacks.sh" \
  -e K8S_DEBUG="1" \
  streamplace/kube-for-mac:latest stop
ba64f1299f15d21739402193165f5607a7be68358adb3147f030c6bbd9997e1a
Wait for stop: .......OK

[...much, much cruft...]

Cleanup Docker Alpine folder...
Remove our specific hacks folder...
```

Your Docker for Mac is now back to its original state. You can create another K8s cluster, or do any other work you wish.

That is all.

