
.PHONY: all push

all: .
	docker build -t streamplace/kube-for-mac .

push: .
	docker push streamplace/kube-for-mac
