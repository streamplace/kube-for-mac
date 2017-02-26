
# kube-for-mac

Last night I got Kubernetes running on Docker for Mac.

I'm not sure if this is evil or not yet. Certainly both the Docker and Kubernetes teams tell you
not to do it. So. Use at your own risk. ¯\\_(ツ)_/¯

## How do?

I like to start with a Docker factory reset first. Because then you know where the button is when
this script totally hoses your Docker VM and you need to start over. Then:

```
docker run --rm --privileged -v /:/rootfs streamplace/kube-for-mac
```

## Now what?

Because the Kubernetes server takes over port 8080 on the Docker VM, we can't easily forward local
port 8080 to your local Kubernetes cluster. So you might wanna throw this in your `~/.kube/config`:

```
apiVersion: v1
clusters:
- cluster:
    server: http://localhost:8888
  name: kube-for-mac
contexts:
- context:
    cluster: kube-for-mac
    namespace: default
    user: kube-for-mac
  name: kube-for-mac
current-context: kube-for-mac
kind: Config
preferences: {}
users:
- name: kube-for-mac
```
