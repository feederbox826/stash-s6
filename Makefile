user=stashapp
repo=stash
tag=latest

IS_WIN_SHELL =
ifeq (${SHELL}, sh.exe)
	IS_WIN_SHELL = true
endif
ifeq (${SHELL}, cmd)
	IS_WIN_SHELL = true
endif

ifdef IS_WIN_SHELL
	RM := del /s /q
	RMDIR := rmdir /s /q
	NOOP := @@
else
	RM := rm -f
	RMDIR := rm -rf
	NOOP := @:
endif

.PHONY: build-info
build-info:
ifndef BUILD_DATE
	$(eval BUILD_DATE := $(shell go run scripts/getDate.go))
endif
ifndef GITHASH
	$(eval GITHASH := $(shell git rev-parse --short HEAD))
endif
ifndef STASH_VERSION
	$(echo "STASHVERS")
endif
ifndef OFFICIAL_BUILD
	$(eval OFFICIAL_BUILD := false)
endif
ifndef DOCKER_BUILD_ARGS
	DOCKER_BUILD_ARGS = --build-arg BUILD_DATE="$(BUILD_DATE)" --build-arg GITHASH="$(GITHASH)" --build-arg STASH_VERSION="$(STASH_VERSION)" --build-arg OFFICIAL_BUILD="$(OFFICIAL_BUILD)"
endif

.PHONY: docker-build-base
docker-base: docker-bin
	docker build ${DOCKER_BUILD_ARGS} --tag ${repo}:base --file dockerfile/ci-copy.Dockerfile .

.PHONY: docker-hwaccel-base
docker-hwaccel-base: docker-bin
	docker build ${DOCKER_BUILD_ARGS} --tag ${repo}:hwaccel-base --file dockerfile/hwaccel-base.Dockerfile .

.PHONY: docker-hwaccel-deb
docker-hwaccel-deb: docker-hwaccel-base
	docker build --build-arg UPSTREAM_IMAGE="${repo}:hwaccel-base" --tag ${repo}:${tag}-hwaccel-deb --file dockerfile/hwaccel-deb.Dockerfile .

.PHONY: docker-hwaccel-jf
docker-hwaccel-jf: docker-hwaccel-base
	docker build --build-arg UPSTREAM_IMAGE="${repo}:hwaccel-base" --tag ${repo}:${tag}-hwaccel-jf --file dockerfile/hwaccel-jf.Dockerfile .

.PHONY: docker-alpine
docker-alpine: docker-bin
	docker build ${DOCKER_BUILD_ARGS} --tag ${repo}:${tag}-alpine --file dockerfile/alpine.Dockerfile .

.PHONY: docker-build-all
docker-all: docker-hwaccel-deb docker-hwaccel-jf docker-alpine