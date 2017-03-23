#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/common.sh"

bigLog "Adding necessary dependency findmnt..."
onVM apk update
onVM apk add findmnt

# I have no idea why this is, but once kubelet starts running it expects mount to be at /mount.
bigLog "Copying mount for poorly-understood reasons..."
onVM cp /bin/mount /mount

bigLog "Creating /var/lib/kubelet bind"
onVM mkdir -p /var/lib/kubelet
onVM mount -o bind /var/lib/kubelet /var/lib/kubelet
onVM mount --make-shared /var/lib/kubelet

bigLog "Removing stale containers..."
containers="kubelet k8s-proxy-1 k8s-proxy-2"
for container in $containers; do
  onVM docker rm -f $container > /dev/null || echo "No need to clean up $container"
done

bigLog "Starting kubelet..."
onVM docker run \
  --net=host \
  --pid=host \
  --privileged \
  --volume=/:/rootfs:ro \
  --volume=/sys:/sys:ro \
  --volume=/var/run:/var/run:rw \
  --volume=/var/lib/docker/:/var/lib/docker:rw \
  --volume=/var/lib/kubelet/:/var/lib/kubelet:shared \
  --name=kubelet \
  -d \
  gcr.io/google_containers/hyperkube-amd64:v${K8S_VERSION:-1.5.5} \
  /hyperkube kubelet \
    --address="0.0.0.0" \
    --containerized \
    --hostname-override="127.0.0.1" \
    --api-servers=http://localhost:8080 \
    --pod-manifest-path=/etc/kubernetes/manifests \
    --cluster-dns=10.0.0.10 \
    --cluster-domain=cluster.local \
    --allow-privileged=true --v=2

onVM rm -rf /tmp/kubernetes.sock

bigLog "Running proxy part one..."
onVM docker run \
  --name=k8s-proxy-1 \
  -d \
  --net=host \
  -v /tmp:/hostrun \
  verb/socat \
    UNIX-LISTEN:/hostrun/kubernetes.sock,fork TCP:127.0.0.1:8080

bigLog "Running proxy part two..."
onVM docker run \
  --name=k8s-proxy-2 \
  -d \
  -p 8888:8080 \
  -v /tmp:/hostrun \
  verb/socat \
    TCP-LISTEN:8080,fork UNIX-CONNECT:/hostrun/kubernetes.sock


bigLog "Done. Give it like three minutes than see if you can curl localhost:8888."

bigLog "This container has to keep running because of a strange kube-for-mac file watching bug. https://git.io/vSejZ"
tail -f /dev/null
