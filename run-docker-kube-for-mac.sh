#!/bin/bash
# docker-kube-for-mac.sh, ABr
# Run kubernetes natively on Mac OsX
# See https://github.com/streamplace/kube-for-mac

# HOW TO RUN:
# 1. Determine your Kubernetes version (default value is *very old*)
#
#      DOCKER_KUBE_FOR_MAC_K8S_VERSION=1.7.0
#
# 2. If necessary, create a wrapper script to load in any files or
#    take other actions. For example, take a look at:
#
#      ./hacks/v${DOCKER_KUBE_FOR_MAC_K8S_VERSION}/run
#
# 3. Start Kube-for-Mac (directly or using a wrapper script). The below
#    uses a wrapper script to account for v1.7.0 we defined above:
#
#      ./hacks/v${DOCKER_KUBE_FOR_MAC_K8S_VERSION}/run ./run-docker-kube-for-mac.sh start
#
#    Starting with k8s v1.7.0 things are broken. We had to do a lot of work.
#    So there is *another* script to run to get addons deployed. Sigh.
#
#      ./kube-for-mac/hacks/v${DOCKER_KUBE_FOR_MAC_K8S_VERSION}/run ./run-docker-kube-for-mac.sh custom source /etc/hacks-in/hacks.sh DEPLOY-ADDONS
#      docker logs -f docker-kube-for-mac-custom
#
# 4. Smoketest if desired. The container should come into being, and should terminate properly.
#
#      kubectl --namespace=default --cluster=kube-for-mac run --rm -it --image alpine my-alpine -- ash
#
#    You can verify networking by using the following in the smoketest shell:
#
#      ping -c 1 kubernetes
#      ping -c 1 google.com
#
# 5. Stop when complete. Use the same wrapper as for start. Example:
#
#      ./hacks/v${DOCKER_KUBE_FOR_MAC_K8S_VERSION}/run ./run-docker-kube-for-mac.sh stop

########################################################################
# globals
g_DOCKER_KUBE_FOR_MAC_IMAGE="${DOCKER_KUBE_FOR_MAC_IMAGE:-streamplace/kube-for-mac:latest}"
g_DOCKER_KUBE_FOR_MAC_K8S_VERSION="${DOCKER_KUBE_FOR_MAC_K8S_VERSION:-1.5.7}"
g_DOCKER_KUBE_FOR_MAC_DOCKER_ARGS="${DOCKER_KUBE_FOR_MAC_DOCKER_ARGS}"
g_DOCKER_KUBE_FOR_MAC_KUBELET_ARGS="${DOCKER_KUBE_FOR_MAC_KUBELET_ARGS}"
g_DOCKER_KUBE_FOR_MAC_LOCAL_DOCKER_ARGS="${DOCKER_KUBE_FOR_MAC_LOCAL_DOCKER_ARGS}"
g_DOCKER_KUBE_FOR_MAC_K8S_HACKS="${DOCKER_KUBE_FOR_MAC_K8S_HACKS}"

########################################################################
# start
function docker-kube-for-mac-x-start {
  local l_container_id=$(docker ps --quiet --filter name=docker-kube-for-mac-start 2>/dev/null)
  [ x"$l_container_id" != x ] && echo 'Container already running.' && return 1

  # allow overrides
  local LOCAL_DOCKER_ARGS="$g_DOCKER_KUBE_FOR_MAC_DOCKER_ARGS"
  local LOCAL_KUBELET_ARGS="$g_DOCKER_KUBE_FOR_MAC_KUBELET_ARGS"
  local LOCAL_K8S_HACKS="$g_DOCKER_KUBE_FOR_MAC_K8S_HACKS"

  echo 'Starting kube-for-mac...'
  local l_docker_run="/tmp/kube-for-mac-$$.start"
  echo "docker run --privileged -v /:/rootfs -v /Users:/Users --net=host \\" > "$l_docker_run"
  [ x"$g_DOCKER_KUBE_FOR_MAC_LOCAL_DOCKER_ARGS" != x ] && echo "  $g_DOCKER_KUBE_FOR_MAC_LOCAL_DOCKER_ARGS \\" >> "$l_docker_run"
  echo "  -d --name docker-kube-for-mac-start \\" >> "$l_docker_run"
  echo "  -e DOCKER_ARGS=\"$LOCAL_DOCKER_ARGS\" \\" >> "$l_docker_run"
  echo "  -e K8S_VERSION=$g_DOCKER_KUBE_FOR_MAC_K8S_VERSION \\" >> "$l_docker_run"
  echo "  -e KUBELET_ARGS=\"$LOCAL_KUBELET_ARGS\" \\" >> "$l_docker_run"
  echo "  -e K8S_HACKS=\"$LOCAL_K8S_HACKS\" \\" >> "$l_docker_run"
  echo "  $g_DOCKER_KUBE_FOR_MAC_IMAGE" >> "$l_docker_run"
  cat "$l_docker_run"
  source "$l_docker_run"
  local l_rc=$?
  rm -f "$l_docker_run"
  [ $l_rc -ne 0 ] && return $l_rc
  echo -n 'Wait for start: '
  local l_ctr=0
  local l_timeout=90
  local l_status=''
  while [ $l_ctr -lt $l_timeout ] ; do
    l_ctr=$((l_ctr + 1))
    l_container_id=$(docker ps --quiet --filter name=docker-kube-for-mac-start 2>/dev/null)
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

    # one more test - can we get kube-system namespace?
    l_status=$(kubectl --server http://localhost:8888 get ns 2>/dev/null | grep -e 'kube-system')
    l_rc=$?
    [ $l_rc -eq 0 ] && [ x"$l_status" = x ] && l_rc=1
    [ $l_rc -ne 0 ] && sleep 5 && echo -n '.' && continue
    break
  done
  [ $l_rc -ne 0 ] && echo '**TIMEOUT**' && return 1
  echo 'OK'

  return 0
}
 
########################################################################
# stop
function docker-kube-for-mac-x-stop {
  local l_docker_run="/tmp/kube-for-mac-$$.stop"

  # allow overrides
  local LOCAL_DOCKER_ARGS="$g_DOCKER_KUBE_FOR_MAC_DOCKER_ARGS"
  local LOCAL_KUBELET_ARGS="$g_DOCKER_KUBE_FOR_MAC_KUBELET_ARGS"
  local LOCAL_K8S_HACKS="$g_DOCKER_KUBE_FOR_MAC_K8S_HACKS"

  echo 'Stopping kube-for-mac...'
  echo "docker run --privileged -v /:/rootfs -v /Users:/Users --net=host \\" > "$l_docker_run"
  [ x"$g_DOCKER_KUBE_FOR_MAC_LOCAL_DOCKER_ARGS" != x ] && echo "  $g_DOCKER_KUBE_FOR_MAC_LOCAL_DOCKER_ARGS \\" >> "$l_docker_run"
  echo "  -d --name docker-kube-for-mac-stop \\" >> "$l_docker_run"
  echo "  -e DOCKER_ARGS=\"$LOCAL_DOCKER_ARGS\" \\" >> "$l_docker_run"
  echo "  -e K8S_VERSION=$g_DOCKER_KUBE_FOR_MAC_K8S_VERSION \\" >> "$l_docker_run"
  echo "  -e KUBELET_ARGS=\"$LOCAL_KUBELET_ARGS\" \\" >> "$l_docker_run"
  echo "  -e K8S_HACKS=\"$LOCAL_K8S_HACKS\" \\" >> "$l_docker_run"
  echo "  $g_DOCKER_KUBE_FOR_MAC_IMAGE stop" >> "$l_docker_run"
  cat "$l_docker_run"
  source "$l_docker_run"
  local l_rc=$?
  rm -f "$l_docker_run"
  [ $l_rc -ne 0 ] && return $l_rc
  echo -n 'Wait for stop: '
  local l_container_id=''
  local l_ctr=0
  local l_timeout=90
  while [ $l_ctr -lt $l_timeout ] ; do
    sleep 1
    l_ctr=$((l_ctr + 1))
    l_container_id=$(docker ps --quiet --filter name=docker-kube-for-mac-stop 2>/dev/null)
    [ x"$l_container_id" != x ] && echo -n '.' && continue
    break
  done
  [ x"$l_container_id" != x ] && echo '**TIMEOUT**' && return 1
  echo 'OK'
  docker logs docker-kube-for-mac-stop
  docker rm --force docker-kube-for-mac-stop >/dev/null 2>&1
  l_container_id=$(docker ps --all --quiet --filter name=docker-kube-for-mac-start 2>/dev/null)
  if [ x"$l_container_id" != x ] ; then
    echo 'Remove kube-for-mac...'
    docker rm --force docker-kube-for-mac-start
    l_rc=$?
    [ $l_rc -ne 0 ] && return $l_rc
  fi
  return 0
}
 
########################################################################
# restart
function docker-kube-for-mac-x-restart {
  docker-kube-for-mac-x-stop
  sleep 3
  docker-kube-for-mac-x-start
}
 
########################################################################
# custom operation
function docker-kube-for-mac-x-custom {
  local l_container_id=$(docker ps --quiet --filter name=docker-kube-for-mac-custom 2>/dev/null)
  [ x"$l_container_id" != x ] && echo 'Container already running.' && return 1

  # allow overrides
  local LOCAL_DOCKER_ARGS="$g_DOCKER_KUBE_FOR_MAC_DOCKER_ARGS"
  local LOCAL_KUBELET_ARGS="$g_DOCKER_KUBE_FOR_MAC_KUBELET_ARGS"
  local LOCAL_K8S_HACKS="$g_DOCKER_KUBE_FOR_MAC_K8S_HACKS"

  echo 'Running custom kube-for-mac...'
  local l_docker_run="/tmp/kube-for-mac-$$.custom"
  echo "docker run --rm --privileged -v /:/rootfs -v /Users:/Users --net=host \\" > "$l_docker_run"
  [ x"$g_DOCKER_KUBE_FOR_MAC_LOCAL_DOCKER_ARGS" != x ] && echo "  $g_DOCKER_KUBE_FOR_MAC_LOCAL_DOCKER_ARGS \\" >> "$l_docker_run"
  echo "  -d --name docker-kube-for-mac-custom \\" >> "$l_docker_run"
  echo "  -e DOCKER_ARGS=\"$LOCAL_DOCKER_ARGS\" \\" >> "$l_docker_run"
  echo "  -e K8S_VERSION=$g_DOCKER_KUBE_FOR_MAC_K8S_VERSION \\" >> "$l_docker_run"
  echo "  -e KUBELET_ARGS=\"$LOCAL_KUBELET_ARGS\" \\" >> "$l_docker_run"
  echo "  -e K8S_HACKS=\"$LOCAL_K8S_HACKS\" \\" >> "$l_docker_run"
  echo "  $g_DOCKER_KUBE_FOR_MAC_IMAGE custom \\" >> "$l_docker_run"
  echo "  $@" >> "$l_docker_run"
  cat "$l_docker_run"
  source "$l_docker_run"
  local l_rc=$?
  rm -f "$l_docker_run"
  [ $l_rc -ne 0 ] && return $l_rc
  return 0
}
 
########################################################################
# optional call support
l_do_run=0
if [ "x$1" != "x" ]; then
  [ "x$1" != "xsource-only" ] && l_do_run=1
fi
if [ $l_do_run -eq 1 ]; then
  l_func="$1"; shift
  [ x"$l_func" != x ] && eval docker-kube-for-mac-x-"$l_func" $*
fi

