# this hack is run for 1.6.3

if [ x"$1" = 'xPRESTART' ] ; then
  # tell user we are here
  echo "Hacking at Docker Alpine..."

  # create folder on alpine docker
  echo "Create folder on Docker Alpine..."
  onVM mkdir -p "/etc/hacks/v$K8S_VERSION/kubelet/etc/kubernetes/manifests"

  # the only way I can find to override the master.json file
  echo "Copy master.json override..."
  copyFile '/etc/hacks-in/kubelet/etc/kubernetes/manifests/master.json' "/etc/hacks/v$K8S_VERSION/kubelet/etc/kubernetes/manifests/master.json"

  # cat it out
  echo "Cat master.json override..."
  onVM cat "/etc/hacks/v$K8S_VERSION/kubelet/etc/kubernetes/manifests/master.json"
fi

if [ x"$1" = 'xCLEANUP' ] ; then
  # tell user we are here
  echo "Cleanup Docker Alpine folder..."

  # create folder on alpine docker
  echo "Remove our specific hacks folder..."
  onVM rm -fR /etc/hacks
fi

