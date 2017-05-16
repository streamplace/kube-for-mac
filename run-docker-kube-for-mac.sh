#!/bin/bash
# run-docker-kube-for-mac.sh, ABr
# Run kubernetes natively on Mac OsX
# See https://github.com/streamplace/kube-for-mac

########################################################################
# globals
g_DOCKER_KUBE_FOR_MAC_IMAGE="${DOCKER_KUBE_FOR_MAC_IMAGE:-dockerregistry.hlsdev.local:5000/hlsdev/kube-for-mac:1.0}"
g_DOCKER_KUBE_FOR_MAC_K8S_VERSION="${DOCKER_KUBE_FOR_MAC_K8S_VERSION:-1.5.7}"
g_DOCKER_KUBE_FOR_MAC_DOCKER_ARGS="${DOCKER_KUBE_FOR_MAC_DOCKER_ARGS}"
g_DOCKER_KUBE_FOR_MAC_KUBELET_ARGS="${DOCKER_KUBE_FOR_MAC_KUBELET_ARGS}"
g_DOCKER_KUBE_FOR_MAC_LOCAL_DOCKER_ARGS="${DOCKER_KUBE_FOR_MAC_LOCAL_DOCKER_ARGS}"
g_DOCKER_KUBE_FOR_MAC_K8S_HACKS="${DOCKER_KUBE_FOR_MAC_K8S_HACKS}"

########################################################################
# start
function run-docker-kube-for-mac-x-start {
  local l_container_id=$(docker ps --quiet --filter name=run-docker-kube-for-mac-start 2>/dev/null)
  [ x"$l_container_id" != x ] && echo 'Container already running.' && return 1

  # allow overrides
  local LOCAL_DOCKER_ARGS="$g_DOCKER_KUBE_FOR_MAC_DOCKER_ARGS"
  local LOCAL_KUBELET_ARGS="$g_DOCKER_KUBE_FOR_MAC_KUBELET_ARGS"
  local LOCAL_K8S_HACKS="$g_DOCKER_KUBE_FOR_MAC_K8S_HACKS"

  echo 'Starting kube-for-mac...'
  local l_docker_run="/tmp/$$.dockerrun"
  echo "docker run --privileged -v /:/rootfs -v /Users:/Users \\" > "$l_docker_run"
	[ x"$g_DOCKER_KUBE_FOR_MAC_LOCAL_DOCKER_ARGS" != x ] && echo "  $g_DOCKER_KUBE_FOR_MAC_LOCAL_DOCKER_ARGS \\" >> "$l_docker_run"
  echo "  -d --name run-docker-kube-for-mac-start \\" >> "$l_docker_run"
  echo "  -e DOCKER_ARGS=\"$LOCAL_DOCKER_ARGS\" \\" >> "$l_docker_run"
  echo "  -e K8S_VERSION=$g_DOCKER_KUBE_FOR_MAC_K8S_VERSION \\" >> "$l_docker_run"
  echo "  -e KUBELET_ARGS=\"$LOCAL_KUBELET_ARGS\" \\" >> "$l_docker_run"
  echo "  -e K8S_HACKS=\"$LOCAL_K8S_HACKS\" \\" >> "$l_docker_run"
  echo "  $g_DOCKER_KUBE_FOR_MAC_IMAGE" >> "$l_docker_run"
	cat "$l_docker_run"
	source "$l_docker_run"
  local l_rc=$?
	rm -f "$l_docker_run"
set +x
  [ $l_rc -ne 0 ] && return $l_rc
  echo -n 'Wait for start: '
  local l_ctr=0
  local l_timeout=90
  local l_status=''
  while [ $l_ctr -lt $l_timeout ] ; do
    l_ctr=$((l_ctr + 1))
    l_container_id=$(docker ps --quiet --filter name=run-docker-kube-for-mac-start 2>/dev/null)
    [ x"$l_container_id" = x ] && sleep 5 && echo -n '.' && continue

    # get the status
    l_status=$(docker logs $l_container_id 2>/dev/null | grep -e '^>\+\s\+Done\.')
    [ x"$l_status" = x ] && sleep 5 && echo -n '.' && continue
    break
  done
  [ x"$l_container_id" = x ] && echo '**CONTAINER NOT FOUND**' && return 1
  [ x"$l_status" = x ] && echo '**TIMEOUT**' && return 1

  # wait for container to be available
  echo 'OK'
  echo -n 'Wait for server: '
  l_ctr=0
  l_timeout=56
  while [ $l_ctr -lt $l_timeout ] ; do
    l_ctr=$((l_ctr + 1))
    curl localhost:8888 >/dev/null 2>&1
    l_rc=$?
    [ $l_rc -ne 0 ] && sleep 5 && echo -n '.' && continue
    break
  done
  [ $l_rc -ne 0 ] && echo '**TIMEOUT**' && return 1
  echo 'OK'
  return 0
}
 
########################################################################
# stop
function run-docker-kube-for-mac-x-stop {
  echo 'Stopping kube-for-mac...'
  docker run --rm --privileged -v /:/rootfs -v /Users:/Users \
    -d --name=run-docker-kube-for-mac-stop \
    $g_DOCKER_KUBE_FOR_MAC_IMAGE stop
  local l_rc=$?
  [ $l_rc -ne 0 ] && return $l_rc
  echo -n 'Wait for stop: '
  local l_container_id=''
  local l_ctr=0
  local l_timeout=90
  while [ $l_ctr -lt $l_timeout ] ; do
    sleep 1
    l_ctr=$((l_ctr + 1))
    l_container_id=$(docker ps --quiet --filter name=run-docker-kube-for-mac-stop 2>/dev/null)
    [ x"$l_container_id" != x ] && echo -n '.' && continue
    break
  done
  [ x"$l_container_id" != x ] && echo '**TIMEOUT**' && return 1
  echo 'OK'
  l_container_id=$(docker ps --quiet --filter name=run-docker-kube-for-mac-start 2>/dev/null)
  if [ x"$l_container_id" != x ] ; then
    echo 'Remove kube-for-mac...'
    docker rm --force run-docker-kube-for-mac-start
    l_rc=$?
    [ $l_rc -ne 0 ] && return $l_rc
  fi
  return 0
}
 
########################################################################
# restart
function run-docker-kube-for-mac-x-restart {
  run-docker-kube-for-mac-x-stop
  sleep 3
  run-docker-kube-for-mac-x-start
}
 
########################################################################
# optional call support
l_do_run=0
if [ "x$1" != "x" ]; then
  [ "x$1" != "xsource-only" ] && l_do_run=1
fi
if [ $l_do_run -eq 1 ]; then
  l_func="$1"; shift
  [ x"$l_func" != x ] && eval run-docker-kube-for-mac-x-"$l_func" $*
fi

