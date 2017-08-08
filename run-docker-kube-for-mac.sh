#!/bin/bash
# docker-kube-for-mac.sh, ABr
# Run kubernetes natively on Mac OsX
# See https://github.com/streamplace/kube-for-mac

# HOW TO RUN:
# 0. Don't call this script directly :)
#    Instead, use the 'lcl-k8s4m.sh' wrapper we provide.
#    Just use this script to get an idea of the env variables you can set.
#
# 1. Determine your Kubernetes version (default value below is *very old*)
#
#      DOCKER_KUBE_FOR_MAC_K8S_VERSION=1.7.3
#
#    Turn on debug if you want *lots* of output
#
#      export DOCKER_KUBE_FOR_MAC_K8S_DEBUG=1
#
# 2. If necessary, create a wrapper script to load in any files or
#    take other actions. For example, take a look at:
#
#      ./hacks/v${DOCKER_KUBE_FOR_MAC_K8S_VERSION}/run
#
# 3. Start Kube-for-Mac (directly or using a wrapper script). The below
#    uses a wrapper script to account for v1.7.3 we defined above:
#
#      ./hacks/v${DOCKER_KUBE_FOR_MAC_K8S_VERSION}/run ./run-docker-kube-for-mac.sh start
#
#    Starting with k8s v1.7.0 things are broken. We had to do a lot of work.
#    So there are *more* scripts to run for DNS and Dashboard. Sigh.
#
#      ./kube-for-mac/hacks/v${DOCKER_KUBE_FOR_MAC_K8S_VERSION}/run ./run-docker-kube-for-mac.sh custom source /etc/hacks-in/hacks.sh DEPLOY-DNS
#      ./kube-for-mac/hacks/v${DOCKER_KUBE_FOR_MAC_K8S_VERSION}/run ./run-docker-kube-for-mac.sh custom source /etc/hacks-in/hacks.sh DEPLOY-DASHBOARD
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
g_DOCKER_KUBE_FOR_MAC_CONTROLLERS="scheduler kube-proxy kube-addon-manager"
g_DOCKER_KUBE_FOR_MAC_K8S_DEBUG="${DOCKER_KUBE_FOR_MAC_K8S_DEBUG:-0}"

########################################################################
# start all - assumes from zero
function docker-kube-for-mac-x-start {
  local l_container_id=$(docker ps --quiet --filter name=docker-kube-for-mac-start 2>/dev/null)
  [ x"$l_container_id" != x ] && echo 'Container already running.' && return 1

  # allow overrides
  local LOCAL_DOCKER_ARGS="$g_DOCKER_KUBE_FOR_MAC_DOCKER_ARGS"
  local LOCAL_KUBELET_ARGS="$g_DOCKER_KUBE_FOR_MAC_KUBELET_ARGS"
  local LOCAL_K8S_HACKS="$g_DOCKER_KUBE_FOR_MAC_K8S_HACKS"
  local LOCAL_K8S_DEBUG="$g_DOCKER_KUBE_FOR_MAC_K8S_DEBUG"

  echo 'Starting kube-for-mac...'
  local l_docker_run="/tmp/kube-for-mac-$$.start"
  echo "docker run --privileged -v /:/rootfs -v /Users:/Users --net=host \\" > "$l_docker_run"
  [ x"$g_DOCKER_KUBE_FOR_MAC_LOCAL_DOCKER_ARGS" != x ] && echo "  $g_DOCKER_KUBE_FOR_MAC_LOCAL_DOCKER_ARGS \\" >> "$l_docker_run"
  echo "  -d --name docker-kube-for-mac-start \\" >> "$l_docker_run"
  echo "  -e DOCKER_ARGS=\"$LOCAL_DOCKER_ARGS\" \\" >> "$l_docker_run"
  echo "  -e K8S_VERSION=$g_DOCKER_KUBE_FOR_MAC_K8S_VERSION \\" >> "$l_docker_run"
  echo "  -e KUBELET_ARGS=\"$LOCAL_KUBELET_ARGS\" \\" >> "$l_docker_run"
  echo "  -e K8S_HACKS=\"$LOCAL_K8S_HACKS\" \\" >> "$l_docker_run"
  echo "  -e K8S_DEBUG=\"$LOCAL_K8S_DEBUG\" \\" >> "$l_docker_run"
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
# stop - teardown cluster entirely
function docker-kube-for-mac-x-stop {
  local l_docker_run="/tmp/kube-for-mac-$$.stop"

  # allow overrides
  local LOCAL_DOCKER_ARGS="$g_DOCKER_KUBE_FOR_MAC_DOCKER_ARGS"
  local LOCAL_KUBELET_ARGS="$g_DOCKER_KUBE_FOR_MAC_KUBELET_ARGS"
  local LOCAL_K8S_HACKS="$g_DOCKER_KUBE_FOR_MAC_K8S_HACKS"
  local LOCAL_K8S_DEBUG="$g_DOCKER_KUBE_FOR_MAC_K8S_DEBUG"

  echo 'Stopping kube-for-mac...'
  echo "docker run --privileged -v /:/rootfs -v /Users:/Users --net=host \\" > "$l_docker_run"
  [ x"$g_DOCKER_KUBE_FOR_MAC_LOCAL_DOCKER_ARGS" != x ] && echo "  $g_DOCKER_KUBE_FOR_MAC_LOCAL_DOCKER_ARGS \\" >> "$l_docker_run"
  echo "  -d --name docker-kube-for-mac-stop \\" >> "$l_docker_run"
  echo "  -e DOCKER_ARGS=\"$LOCAL_DOCKER_ARGS\" \\" >> "$l_docker_run"
  echo "  -e K8S_VERSION=$g_DOCKER_KUBE_FOR_MAC_K8S_VERSION \\" >> "$l_docker_run"
  echo "  -e KUBELET_ARGS=\"$LOCAL_KUBELET_ARGS\" \\" >> "$l_docker_run"
  echo "  -e K8S_HACKS=\"$LOCAL_K8S_HACKS\" \\" >> "$l_docker_run"
  echo "  -e K8S_DEBUG=\"$LOCAL_K8S_DEBUG\" \\" >> "$l_docker_run"
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
  local LOCAL_K8S_DEBUG="$g_DOCKER_KUBE_FOR_MAC_K8S_DEBUG"

  echo 'Running custom kube-for-mac...'
  local l_docker_run="/tmp/kube-for-mac-$$.custom"
  echo "docker run --rm --privileged -v /:/rootfs -v /Users:/Users --net=host \\" > "$l_docker_run"
  [ x"$g_DOCKER_KUBE_FOR_MAC_LOCAL_DOCKER_ARGS" != x ] && echo "  $g_DOCKER_KUBE_FOR_MAC_LOCAL_DOCKER_ARGS \\" >> "$l_docker_run"
  echo "  -d --name docker-kube-for-mac-custom \\" >> "$l_docker_run"
  echo "  -e DOCKER_ARGS=\"$LOCAL_DOCKER_ARGS\" \\" >> "$l_docker_run"
  echo "  -e K8S_VERSION=$g_DOCKER_KUBE_FOR_MAC_K8S_VERSION \\" >> "$l_docker_run"
  echo "  -e KUBELET_ARGS=\"$LOCAL_KUBELET_ARGS\" \\" >> "$l_docker_run"
  echo "  -e K8S_HACKS=\"$LOCAL_K8S_HACKS\" \\" >> "$l_docker_run"
  echo "  -e K8S_DEBUG=\"$LOCAL_K8S_DEBUG\" \\" >> "$l_docker_run"
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
# docker container status
function docker-kube-for-mac-i-docker-container-status {
  local i_docker_container_id="$1"

  # locals
  local l_rc=0
  local l_docker_container_is_running=''
  local l_docker_container_is_paused=''

  # analyze
  l_docker_container_is_running="$(docker inspect -f {{.State.Running}} $i_docker_container_id)"
  l_rc=$?
  [ $l_rc -ne 0 ] && echo "Unknown Docker ID '$l_docker_container_id'" && return $l_rc
  l_docker_container_is_paused="$(docker inspect -f {{.State.Paused}} $i_docker_container_id)"
  l_rc=$?
  [ $l_rc -ne 0 ] && echo "Unknown Docker ID '$l_docker_container_id'" && return $l_rc
  if [ x"$l_docker_container_is_paused" = xtrue ] ; then
    l_docker_container_status='paused'
  elif [ x"$l_docker_container_is_running" = xtrue ] ; then
    l_docker_container_status='running'
  else
    l_docker_container_status='stopped'
  fi
  echo "$l_docker_container_status"
  return 0
}

########################################################################
# pause a running cluster
function docker-kube-for-mac-x-pause {
  # get expected 'start' container - it must already be there
  local l_start_container_id=$(docker ps -a --no-trunc --quiet --filter name=docker-kube-for-mac-start 2>/dev/null)
  [ x"$l_start_container_id" = x ] && echo 'Start Container missing.' && return 1

  # locals
  local l_rc=0
  local l_state_dir=''
  local l_state_file=''
  local l_tmp_file_prefix=''
  local l_tmp_file_1=''
  local l_tmp_file_2=''
  local l_tmp_file_3=''
  local l_tmp_file_4=''
  local l_line_1=''
  local l_line_2=''
  local l_pod_namespace=''
  local l_pod_name=''
  local l_pod_container_name=''
  local l_pod_container_id=''
  local l_pod_container_status=''
  local l_docker_pod_container_id=''
  local l_docker_container_id=''
  local l_docker_container_status=''
  local l_kubelet_id=''

  # temporary files
  l_tmp_file_prefix="/tmp/docker-kube-for-mac-x-pause-$$"
  l_tmp_file_sql="${l_tmp_file_prefix}.sql"
  l_tmp_file_1="${l_tmp_file_prefix}.1"
  l_tmp_file_2="${l_tmp_file_prefix}.2"
  l_tmp_file_3="${l_tmp_file_prefix}.3"
  l_tmp_file_4="${l_tmp_file_prefix}.4"

  # stop kubelet first (no need for pause)
  l_kubelet_id=$(docker ps -a --no-trunc --filter "name=kubelet" -q)
  [ x"$l_kubelet_id" = x ] && echo 'Kubelet not available' && return 1
  echo "Kubelet=$l_kubelet_id"
  l_docker_container_status="$(docker-kube-for-mac-i-docker-container-status $l_kubelet_id)"
  l_rc=$?
  [ $l_rc -ne 0 ] && echo 'Failed query Kubelet' && rm -f ${l_tmp_file_prefix}* && return $l_rc
  if [ x"$l_docker_container_status" = xrunning ] ; then
    echo "  Stop Kubelet..."
    docker stop $l_kubelet_id
    l_rc=$?
    [ $l_rc -ne 0 ] && echo 'Failed stopping Kubelet' && rm -f ${l_tmp_file_prefix}* && return $l_rc
  fi

  # state file to track docker IDs for restart
  l_state_dir="$HOME/.docker-kube-for-mac"
  l_state_file="${l_state_dir}/pause-state"
  mkdir -p "$l_state_dir"
  l_rc=$?
  [ $l_rc -ne 0 ] && echo "Failed creating '$l_state_dir'" && rm -f ${l_tmp_file_prefix}* && return $l_rc
  echo '' > "$l_state_file"
  l_rc=$?
  [ $l_rc -ne 0 ] && echo "Failed accessing '$l_state_file'" && rm -f ${l_tmp_file_prefix}* && return $l_rc
  sqlite3 -column -header "$l_state_file" 'create table pause_state(ids integer primary key, namespace text, pod_name text, docker_pod_container_id text, container_name text, container_id text, state text);'

  # save information on all known pods to state file
  echo "Read all pod information..."
  kubectl get pods --all-namespaces | tail -n +2 > "$l_tmp_file_1"
  l_rc=$?
  [ $l_rc -ne 0 ] && echo "Failed reading pod info" && rm -f ${l_tmp_file_prefix}* && return $l_rc
  while IFS='' read -r l_line_1 || [[ -n "$l_line_1" ]]; do
    # extract basic kubernetes info
    l_pod_namespace="$(echo "$l_line_1" | awk '{print $1}')"
    l_pod_name="$(echo "$l_line_1" | awk '{print $2}')"

    # for the current pod: read docker POD container (runs a 'pause' application')
    l_docker_pod_container_id="$(docker ps -a --no-trunc | grep -e "$l_pod_name" | grep POD | awk '{print $1}')"
    l_rc=$?
    [ $l_rc -ne 0 ] && echo "Unable to locate Docker POD" && rm -f ${l_tmp_file_prefix}* && return $l_rc

    # extract expanded kubernetes info
    echo "  Process $l_pod_namespace:$l_pod_name..."
    kubectl get pod --namespace $l_pod_namespace -o json $l_pod_name > "$l_tmp_file_2"
    l_rc=$?
    [ $l_rc -ne 0 ] && echo "Failed reading pod info" && rm -f ${l_tmp_file_prefix}* && return $l_rc
    #cat "$l_tmp_file_2"

    # extract the name, container ID, and running state as a single list with key/value pairs
    jq '[.status.containerStatuses[] | {f1_name: .name, f2_id: .containerID, f3_state: [.state | to_entries[] | {key}][0].key}]' "$l_tmp_file_2" > "$l_tmp_file_3"
    l_rc=$?
    [ $l_rc -ne 0 ] && echo "Failed translating pod info to key/value pairs" && rm -f ${l_tmp_file_prefix}* && return $l_rc
    #cat "$l_tmp_file_3"

    # convert the key/value pairs to CSV (double-quotes around each field; keys are sorted to known order)
    jq -r '(map(keys) | add | unique | sort) as $cols | map(. as $row | $cols | map($row[.])) as $rows | $rows[] | @csv' "$l_tmp_file_3" > "$l_tmp_file_4"
    l_rc=$?
    [ $l_rc -ne 0 ] && echo "Failed translating pod info to CSV" && rm -f ${l_tmp_file_prefix}* && return $l_rc
    #cat "$l_tmp_file_4"

    # process each line, which is made up of comma-delimited and *quoted* values
    while IFS='' read -r l_line_2 || [[ -n "$l_line_2" ]]; do
      l_pod_container_name="$(echo "$l_line_2" | awk -F'"' '{print $2}')"
      l_pod_container_id="$(echo "$l_line_2" | awk -F'"' '{print $4}')"
      l_pod_container_status="$(echo "$l_line_2" | awk -F'"' '{print $6}')"
      #echo "l_pod_container_name='$l_pod_container_name'; l_pod_container_id='$l_pod_container_id'; l_pod_container_status='$l_pod_container_status'; l_docker_container_id='$l_docker_container_id'"

      # now we need to translate the container ID (assume 'docker' format)
      l_docker_container_id="$(echo "$l_pod_container_id" | sed -e 's#^docker://\(.*\)#\1#')"
      #echo "l_docker_container_id='$l_docker_container_id'"

      # query *docker* for the status (not kubernetes)
      l_docker_container_status="$(docker-kube-for-mac-i-docker-container-status $l_docker_container_id)"
      l_rc=$?
      [ $l_rc -ne 0 ] && echo "Unknown Docker ID '$l_docker_container_id'" && rm -f ${l_tmp_file_prefix}* && return $l_rc
      #echo "l_docker_container_is_running='$l_docker_container_is_running'; l_rc='$l_rc'"
      echo "    $l_pod_container_name: Status=$l_pod_container_status; ID=$l_docker_container_id ($l_docker_container_status)"

      # we can finally generate the sql statement (dump any existing element)
      echo "delete from pause_state where namespace='$l_pod_namespace' and pod_name='$l_pod_name' and container_name='$l_pod_container_name';" > "$l_tmp_file_sql"
      echo 'insert into pause_state(namespace, pod_name, docker_pod_container_id, container_name, container_id, state)' >> "$l_tmp_file_sql"
      echo "  values('$l_pod_namespace', '$l_pod_name', '$l_docker_pod_container_id', '$l_pod_container_name', '$l_docker_container_id', '$l_docker_container_status');" >> "$l_tmp_file_sql"
      #cat "$l_tmp_file_sql"
      sqlite3 "$l_state_file" < "$l_tmp_file_sql"
      l_rc=$?
      [ $l_rc -ne 0 ] && echo "Failed insert" && rm -f ${l_tmp_file_prefix}* && return $l_rc
    done < "$l_tmp_file_4"
  done < "$l_tmp_file_1"

  # stop control programs
  for i in $g_DOCKER_KUBE_FOR_MAC_CONTROLLERS ; do
    # read the *pod* for this program
    l_pod_name="$(sqlite3 "$l_state_file" "select distinct pod_name from pause_state where namespace='kube-system' and container_name='$i'")"
    echo "Stop pod '$l_pod_name'..."

    # stop the individual pods
    for j in $(sqlite3 "$l_state_file" "select container_id from pause_state where namespace='kube-system' and pod_name='$l_pod_name'") ; do
      l_docker_container_is_running="$(docker inspect -f {{.State.Running}} $j)"
      if [ x"$l_docker_container_is_running" = xtrue ] ; then
        docker stop $j
      fi
    done
  done

  # freeze (docker pause) all non-system pods
  for i in $(sqlite3 "$l_state_file" "select container_id from pause_state where namespace!='kube-system'") ; do
    l_docker_container_status="$(docker-kube-for-mac-i-docker-container-status $i)"
    if [ x"$l_docker_container_status" != xpaused ] ; then
      docker pause $i
    fi
  done

  # stop everything else
  for i in $(sqlite3 "$l_state_file" "select container_id from pause_state where namespace='kube-system'") ; do
    l_docker_container_status="$(docker-kube-for-mac-i-docker-container-status $i)"
    if [ x"$l_docker_container_status" = xrunning ] ; then
      docker stop $i
    fi
  done

  # pause the POD programs (STOP doesn't work)
  for i in $(sqlite3 "$l_state_file" "select distinct docker_pod_container_id from pause_state") ; do
    l_docker_container_status="$(docker-kube-for-mac-i-docker-container-status $i)"
    if [ x"$l_docker_container_status" != xpaused ] ; then
      docker pause $i
    fi
  done

  # pause the 'start' container
  l_docker_container_status="$(docker-kube-for-mac-i-docker-container-status $l_start_container_id)"
  if [ x"$l_docker_container_status" != xpaused ] ; then
    docker pause $l_start_container_id
  fi

  # stop the proxy containers
  for i in k8s-proxy-1 k8s-proxy-2 ; do
    l_docker_container_id=$(docker ps --no-trunc -a -f "name=$i" | grep -w "$i" | awk '{print $1}')
    l_docker_container_status="$(docker-kube-for-mac-i-docker-container-status $l_docker_container_id)"
    if [ x"$l_docker_container_status" = xrunning ] ; then
      docker stop $l_docker_container_id
    fi
  done

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

