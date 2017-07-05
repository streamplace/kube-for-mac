#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export CONTAINER_NAMES="kubelet k8s-proxy-1 k8s-proxy-2"

create_token() {
  echo $(cat /dev/urandom | base64 | tr -d "=+/" | dd bs=32 count=1 2> /dev/null)
}

onVM() {
  nsenter --mount=/rootfs/proc/1/ns/mnt -- "$@"
}

docker() {
  onVM docker "$@"
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

# starting with v1.7.0, we must roll our own tls
handle_tls() {
  # location of tls certs
  # normally: /etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes
  local i_cert_dir="${1:-/etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes}" ; shift

  # Additional address of the API server to be added to the
  # list of Subject Alternative Names of the server TLS certificate
  # Should contain internal IP, i.e. IP:10.0.0.1 for 10.0.0.0/24 cluster IP range
  local i_extra_sans="${1:-IP:10.0.0.1,DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster.local}" ; shift

  # other locals
  local cert_ip=''
  local extra_sans=''
  local cert_dir="$i_cert_dir"
  local cert_group='kube-cert'

  # Files in /data are persistent across reboots, so we don't want to re-create the files if they already
  # exist, because the state is persistent in etcd too, and we don't want a conflict between "old" data in
  # etcd and "new" data that this script would create for apiserver. Therefore, if the file exist, skip it.
  if onVM [[ ! -f ${i_cert_dir}/ca.crt ]]; then
    # we need the host IP address
    cert_ip=$(onVM ip a show dev eth0 | grep -e 'inet ' | awk '{print $2}' | awk -F'/' '{print $1}')

    # make the CA certs
    extra_sans="${i_extra_sans}"
    source ${DIR}/make-ca-cert.sh "$cert_ip" "$extra_sans" "$cert_dir" "$cert_group"
    bigLog "Certificates created $(date)"
  else
    bigLog "Certificates already found, not recreating."
  fi

  if onVM [[ ! -f ${i_cert_dir}/basic_auth.csv ]]; then
    # Create basic token authorization
    onVM ash -c "echo 'admin,admin,admin' > ${i_cert_dir}/basic_auth.csv"
    bigLog "basic_auth.csv created $(date)"
    onVM chmod 644 ${i_cert_dir}/basic_auth.csv
  else
    bigLog "basic_auth.csv already found, not recreating."
  fi

  if onVM [[ ! -f ${i_cert_dir}/known_tokens.csv ]]; then
    # Create known tokens for service accounts
    onVM ash -c "echo '$(create_token),admin,admin' >> ${i_cert_dir}/known_tokens.csv"
    onVM ash -c "echo '$(create_token),kubelet,kubelet' >> ${i_cert_dir}/known_tokens.csv"
    onVM ash -c "echo '$(create_token),kube_proxy,kube_proxy' >> ${i_cert_dir}/known_tokens.csv"
    onVM chmod 644 ${i_cert_dir}/known_tokens.csv

    bigLog "known_tokens.csv created $(date)"
  else
    bigLog "known_tokens.csv already found, not recreating."
  fi
}

runWatcher() {
  onVM docker run \
    -d \
    --privileged \
    -v /:/rootfs \
    -v /Users:/Users \
    streamplace/kube-for-mac /watcher-fix.sh "${1:-}"
}

