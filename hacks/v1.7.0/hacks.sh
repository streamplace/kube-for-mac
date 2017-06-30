# this hack is run for 1.7.0

if [ x"$1" = 'xPRESTART' ] ; then
  # tell user we are here
  echo "Hacking at Docker Alpine..."

  # create folder on alpine docker
  echo "Create folders on Docker Alpine..."
  onVM mkdir -p "/etc/hacks/v$K8S_VERSION/kubelet/etc/kubernetes/manifests"
  onVM mkdir -p "/etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes"
  onVM mkdir -p "/etc/hacks/v$K8S_VERSION/kube-addon-manager/etc/kubernetes/addons"

  # starting with v1.7.0 default manifests aren't created
  echo "Copy kubelet manifests..."
  copyFile '/etc/hacks-in/kubelet/etc/kubernetes/manifests/addon-manager-singlenode.json' "/etc/hacks/v$K8S_VERSION/kubelet/etc/kubernetes/manifests/addon-manager-singlenode.json"
  copyFile '/etc/hacks-in/kubelet/etc/kubernetes/manifests/etcd.json' "/etc/hacks/v$K8S_VERSION/kubelet/etc/kubernetes/manifests/etcd.json"
  copyFile '/etc/hacks-in/kubelet/etc/kubernetes/manifests/kube-proxy.json' "/etc/hacks/v$K8S_VERSION/kubelet/etc/kubernetes/manifests/kube-proxy.json"
  copyFile '/etc/hacks-in/kubelet/etc/kubernetes/manifests/master.json' "/etc/hacks/v$K8S_VERSION/kubelet/etc/kubernetes/manifests/master.json"

  echo "Copy apiserver tls..."
  copyFile '/etc/hacks-in/apiserver/srv/kubernetes/basic_auth.csv' "/etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes/basic_auth.csv"
  copyFile '/etc/hacks-in/apiserver/srv/kubernetes/ca.crt' "/etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes/ca.crt"
  copyFile '/etc/hacks-in/apiserver/srv/kubernetes/known_tokens.csv' "/etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes/known_tokens.csv"
  copyFile '/etc/hacks-in/apiserver/srv/kubernetes/kubecfg.crt' "/etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes/kubecfg.crt"
  copyFile '/etc/hacks-in/apiserver/srv/kubernetes/kubecfg.key' "/etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes/kubecfg.key"
  copyFile '/etc/hacks-in/apiserver/srv/kubernetes/server.cert' "/etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes/server.cert"
  copyFile '/etc/hacks-in/apiserver/srv/kubernetes/server.key' "/etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes/server.key"

  echo "Set perms for apiserver tls..."
  onVM chown root:999 /etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes/ca.crt
  onVM chown root:999 /etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes/server.cert
  onVM chown root:999 /etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes/server.key
  onVM chmod 644 /etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes/basic_auth.csv
  onVM chmod 660 /etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes/ca.crt
  onVM chmod 644 /etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes/known_tokens.csv
  onVM chmod 600 /etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes/kubecfg.crt
  onVM chmod 600 /etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes/kubecfg.key
  onVM chmod 660 /etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes/server.cert
  onVM chmod 660 /etc/hacks/v$K8S_VERSION/apiserver/srv/kubernetes/server.key

  echo "Copy kube-addon-manager manifests..."
  set -x
  copyFile '/etc/hacks-in/kube-addon-manager/etc/kubernetes/addons/dashboard-controller.yaml' "/etc/hacks/v$K8S_VERSION/kube-addon-manager/etc/kubernetes/addons/dashboard-controller.yaml" 
  copyFile '/etc/hacks-in/kube-addon-manager/etc/kubernetes/addons/dashboard-service.yaml' "/etc/hacks/v$K8S_VERSION/kube-addon-manager/etc/kubernetes/addons/dashboard-service.yaml" 
  copyFile '/etc/hacks-in/kube-addon-manager/etc/kubernetes/addons/kubedns-cm.yaml' "/etc/hacks/v$K8S_VERSION/kube-addon-manager/etc/kubernetes/addons/kubedns-cm.yaml" 
  copyFile '/etc/hacks-in/kube-addon-manager/etc/kubernetes/addons/kubedns-controller.yaml' "/etc/hacks/v$K8S_VERSION/kube-addon-manager/etc/kubernetes/addons/kubedns-controller.yaml" 
  copyFile '/etc/hacks-in/kube-addon-manager/etc/kubernetes/addons/kubedns-sa.yaml' "/etc/hacks/v$K8S_VERSION/kube-addon-manager/etc/kubernetes/addons/kubedns-sa.yaml" 
  copyFile '/etc/hacks-in/kube-addon-manager/etc/kubernetes/addons/kubedns-svc.yaml' "/etc/hacks/v$K8S_VERSION/kube-addon-manager/etc/kubernetes/addons/kubedns-svc.yaml" 
fi

if [ x"$1" = 'xCLEANUP' ] ; then
  # tell user we are here
  echo "Cleanup Docker Alpine folder..."

  # create folder on alpine docker
  echo "Remove our specific hacks folder..."
  onVM rm -fR /etc/hacks/v$K8S_VERSION
fi

