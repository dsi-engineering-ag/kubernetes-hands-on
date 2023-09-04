TAG=latest

docker:
	docker build . -t ghcr.io/dsi-engineering-ag/kubernetes-hands-on-sampleapp:${TAG}

# docker login -u USERNAME -p TOKEN ghcr.io
push:
	docker push ghcr.io/dsi-engineering-ag/kubernetes-hands-on-sampleapp:${TAG}
