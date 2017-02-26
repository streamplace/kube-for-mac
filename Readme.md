
# kube-for-mac

Last night I got Kubernetes running on Docker for Mac.

I'm not sure if this is evil or not yet. Certainly both the Docker and Kubernetes teams tell you
not to do it. So. ¯\\_(ツ)_/¯

## How do?

I like to start with a Docker factory reset first. Because then you know where the button is when
this script totally hoses your Docker VM and you need to start over. Then:

```
docker run --rm --privileged -v /:/rootfs streamplace/kube-for-mac
```
