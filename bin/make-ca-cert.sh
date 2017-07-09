#!/bin/bash
# adapted from Kubernetes to run on Docker kube-for-mac

set -o errexit
set -o nounset
set -o pipefail

DEBUG="${DEBUG:-false}"

if [ "${DEBUG}" == "true" ]; then
  set -x
fi

# get variables
cert_ip=$1
extra_sans=${2:-}
cert_dir=${3:-/srv/kubernetes}
cert_group=${4:-kube-cert}

# setup docker VM
if ! onVM which openssl ; then
  bigLog "Adding necessary dependency openssl..."
  onVM apk update
  onVM apk add openssl
fi
onVM mkdir -p "$cert_dir"

# setup alternative names
sans="IP:${cert_ip}"
if [[ -n "${extra_sans}" ]]; then
  sans="${sans},${extra_sans}"
fi

tmpdir=$(onVM mktemp -d -t kubernetes_cacert.XXXXXX)
trap 'onVM rm -Rf "${tmpdir}"' EXIT

# TODO: For now, this is a patched tool that makes subject-alt-name work
onVM ash -c "cd ${tmpdir}; curl -L -O https://storage.googleapis.com/kubernetes-release/easy-rsa/easy-rsa.tar.gz > /dev/null 2>&1"
onVM ash -c "cd ${tmpdir}; tar xzf easy-rsa.tar.gz > /dev/null 2>&1"

# create the CA
onVM ash -c "cd ${tmpdir}/easy-rsa-master/easyrsa3; ./easyrsa init-pki > /dev/null 2>&1"
onVM ash -c "cd ${tmpdir}/easy-rsa-master/easyrsa3; ./easyrsa --batch '--req-cn=$cert_ip@`date +%s`' build-ca nopass > /dev/null 2>&1"

# issue the server cert
onVM ash -c "cd ${tmpdir}/easy-rsa-master/easyrsa3; ./easyrsa --subject-alt-name='${sans}' build-server-full kubernetes-master nopass > /dev/null 2>&1";
onVM ash -c "cd ${tmpdir}/easy-rsa-master/easyrsa3; cp -p pki/issued/kubernetes-master.crt '${cert_dir}/server.cert' > /dev/null 2>&1"
onVM ash -c "cd ${tmpdir}/easy-rsa-master/easyrsa3; cp -p pki/private/kubernetes-master.key '${cert_dir}/server.key' > /dev/null 2>&1"

# Make a superuser client cert with subject "O=system:masters, CN=kubecfg"
onVM ash -c "cd ${tmpdir}/easy-rsa-master/easyrsa3; ./easyrsa --dn-mode=org --req-cn=kubecfg --req-org=system:masters --req-c= --req-st= --req-city= --req-email= --req-ou= build-client-full kubecfg nopass > /dev/null 2>&1"
onVM ash -c "cd ${tmpdir}/easy-rsa-master/easyrsa3; cp -p pki/ca.crt '${cert_dir}/ca.crt'"
onVM ash -c "cd ${tmpdir}/easy-rsa-master/easyrsa3; cp -p pki/issued/kubecfg.crt '${cert_dir}/kubecfg.crt'"
onVM ash -c "cd ${tmpdir}/easy-rsa-master/easyrsa3; cp -p pki/private/kubecfg.key '${cert_dir}/kubecfg.key'"

# Make server certs accessible to apiserver - the '999' is the observed value for kube-cert
onVM chown root:999 "${cert_dir}/ca.crt"
onVM chown root:999 "${cert_dir}/server.cert"
onVM chown root:999 "${cert_dir}/server.key"
onVM chmod 660 "${cert_dir}/ca.crt"
onVM chmod 660 "${cert_dir}/server.cert"
onVM chmod 660 "${cert_dir}/server.key"

# cleanup
onVM rm -Rf "${tmpdir}"

