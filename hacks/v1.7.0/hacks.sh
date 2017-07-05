# this hack is run for 1.7.0

if [ x"$1" = 'xPRESTART' ] ; then
  # tell user we are here
  echo "Hacking at Docker Alpine..."

  # create folder on alpine docker
  echo "Create folders on Docker Alpine..."
  onVM mkdir -p "/etc/hacks/v$K8S_VERSION/kubelet/etc/kubernetes/manifests"
  onVM mkdir -p "/etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes"
  onVM mkdir -p "/etc/hacks/v$K8S_VERSION/kube-addon-manager/etc/kubernetes/addons"
  onVM mkdir -p "/etc/hacks/v$K8S_VERSION/kube-addon-manager/staging"

  # v1.7.0: default manifests aren't created. fudge.
  echo "Copy kubelet manifests..."
  copyFile '/etc/hacks-in/kubelet/etc/kubernetes/manifests/addon-manager-singlenode.json' "/etc/hacks/v$K8S_VERSION/kubelet/etc/kubernetes/manifests/addon-manager-singlenode.json"
  copyFile '/etc/hacks-in/kubelet/etc/kubernetes/manifests/etcd.json' "/etc/hacks/v$K8S_VERSION/kubelet/etc/kubernetes/manifests/etcd.json"
  copyFile '/etc/hacks-in/kubelet/etc/kubernetes/manifests/kube-proxy.json' "/etc/hacks/v$K8S_VERSION/kubelet/etc/kubernetes/manifests/kube-proxy.json"
  copyFile '/etc/hacks-in/kubelet/etc/kubernetes/manifests/master.json' "/etc/hacks/v$K8S_VERSION/kubelet/etc/kubernetes/manifests/master.json"

  # v1.7.0: tls is not automatically initialized either. eck.
  set +e
  bigLog "About to hack TLS..."
  handle_tls
  bigLog "Hacked TLS."
  set -e

  # v1.7.0: addons are not deployed (DNS / dashboard). [urp]
  echo "Copy kube-addon-manager manifests (initial)..."
  copyFile '/etc/hacks-in/kube-addon-manager/etc/kubernetes/addons/dashboard-service.yaml' "/etc/hacks/v$K8S_VERSION/kube-addon-manager/etc/kubernetes/addons/dashboard-service.yaml" 
  copyFile '/etc/hacks-in/kube-addon-manager/etc/kubernetes/addons/kubedns-cm.yaml' "/etc/hacks/v$K8S_VERSION/kube-addon-manager/etc/kubernetes/addons/kubedns-cm.yaml" 
  copyFile '/etc/hacks-in/kube-addon-manager/etc/kubernetes/addons/kubedns-sa.yaml' "/etc/hacks/v$K8S_VERSION/kube-addon-manager/etc/kubernetes/addons/kubedns-sa.yaml" 
  copyFile '/etc/hacks-in/kube-addon-manager/etc/kubernetes/addons/kubedns-svc.yaml' "/etc/hacks/v$K8S_VERSION/kube-addon-manager/etc/kubernetes/addons/kubedns-svc.yaml" 
  echo "Cannot deploy DNS/Dashboard addon controllers now...use DEPLOY-ADDONS option"
fi

if [ x"$1" = 'xDEPLOY-ADDONS' ] ; then
  set +e
  echo 'Wait for kube-addon-manager...'
  the_ctr=0
  the_timeout=60
  while [ $the_ctr -lt $the_timeout ] ; do
    the_ctr=$((the_ctr + 1))
    the_addon_mgr=$(onVM docker ps | grep kube-addon-manager | grep -v POD | awk '{print $1}')
    if [ x"$the_addon_mgr" != x ] ; then
      if onVM docker logs $the_addon_mgr 2>&1 | grep -q -i -e 'Kubernetes addon reconcile completed' ; then
        break
      fi
      the_addon_mgr=''
    fi
    echo -n '.'
    sleep 3
  done
  [ x"$the_addon_mgr" = x ] && echo '***TIMEOUT***' && exit 1
  echo 'OK'
  echo 'Sleeping for 120 seconds...'
  sleep 120

  echo 'Deploy DNS...'
  copyFile '/etc/hacks-in/kube-addon-manager/etc/kubernetes/addons/kubedns-controller.yaml' "/etc/hacks/v$K8S_VERSION/kube-addon-manager/etc/kubernetes/addons/kubedns-controller.yaml" 
  echo -n 'Wait: '
  the_ctr=0
  the_timeout=60
  while [ $the_ctr -lt $the_timeout ] ; do
    the_ctr=$((the_ctr + 1))
    the_dns=$(onVM docker ps 2>&1 | grep k8s-dns-kube-dns-amd64 | awk '{print $1}')
    if [ x"$the_dns" != x ] ; then
      if ! onVM docker logs $the_dns 2>&1 | grep -q -i -e 'ready for queries' ;
      then
        the_dns=''
      fi
    fi
    [ x"$the_dns" != x ] && break
    echo -n '.'
    sleep 3
  done
  [ x"$the_dns" = x ] && echo '***TIMEOUT***' && exit 1
  echo 'OK'
  echo 'Sleeping for 90 seconds...'
  sleep 90

  # we won't wait for this...just do it
  echo -n 'Deploy Dashboard: '
  copyFile '/etc/hacks-in/kube-addon-manager/etc/kubernetes/addons/dashboard-controller.yaml' "/etc/hacks/v$K8S_VERSION/kube-addon-manager/etc/kubernetes/addons/dashboard-controller.yaml" 
  echo 'OK'
fi

if [ x"$1" = 'xCLEANUP' ] ; then
  # tell user we are here
  echo "Cleanup Docker Alpine folder..."

  # create folder on alpine docker
  echo "Remove our specific hacks folder..."
  onVM rm -fR /etc/hacks/v$K8S_VERSION
fi

