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

.PHONY: docker-hwaccel-base
docker-hwaccel-base: build-info
	docker build --build-arg BUILD_DATE="$(BUILD_DATE)" --build-arg GITHASH="$(GITHASH)"" --build-arg STASH_VERSION="$(STASH_VERSION)"" --build-arg OFFICIAL_BUILD=$(OFFICIAL_BUILD) --tag stash:hwaccel-base --file dockerfile/hwaccel-base.Dockerfile .

docker-hwaccel-deb: docker-hwaccel-base
	docker build --tag stash:hwaccel-deb --file dockerfile/hwaccel-deb.Dockerfile .

docker-hwaccel-jf: docker-hwaccel-base
	docker build --tag stash:hwaccel-jf --file dockerfile/hwaccel-jf.Dockerfile .