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

copyFile() {
  local l_src="$1"; shift
  local l_dst="$1"; shift
  local l_flag='>'
  #echo "l_src='$l_src'; l_dst='$l_dst'"
  while IFS='' read -r LINE || [[ -n "$LINE" ]] ; do
    #echo "LINE='$LINE'"
    nsenter --mount=/rootfs/proc/1/ns/mnt -- ash -c "echo '$LINE' $l_flag '$l_dst'"
    l_flag='>>'
  done < "$l_src"
}

runWatcher() {
  onVM docker run \
    -d \
    --privileged \
    -v /:/rootfs \
    -v /Users:/Users \
    streamplace/kube-for-mac /watcher-fix.sh "${1:-}"
}

