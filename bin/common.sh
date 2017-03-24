#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export CONTAINER_NAMES="kubelet k8s-proxy-1 k8s-proxy-2"

onVM() {
  nsenter --mount=/rootfs/proc/1/ns/mnt -- $*
}

docker() {
  onVM docker $*
}

bigLog() {
  echo ""
  echo ">>>>>>> " $*
}

runWatcher() {
  onVM docker run \
    -d \
    --privileged \
    -v /:/rootfs \
    -v /Users:/Users \
    streamplace/kube-for-mac /watcher-fix.sh "${1:-}"
}
