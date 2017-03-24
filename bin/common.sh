#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

onVM() {
  nsenter --mount=/rootfs/proc/1/ns/mnt -- $*
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
