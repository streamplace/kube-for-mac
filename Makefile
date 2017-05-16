
.PHONY: all push

all: .
	docker build -t andybrucenet/kube-for-mac .

push: .
	docker push andybrucenet/kube-for-mac
