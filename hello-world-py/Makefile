image_name := hello-world
gitsha := $(shell git rev-parse HEAD)

define build_image
docker buildx build  \
	--platform linux/amd64,linux/arm64 \
	--push \
	--tag etapau/$(image_name):latest \
	.
endef

define docker_run
docker run \
	-p 9000:9000 $(image_name):latest
endef

run-local:
	$(call docker_run)

image-latest:
	$(call build_image)

image: image-latest

run: run-local