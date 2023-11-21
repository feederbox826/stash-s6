# syntax=docker/dockerfile:1

FROM alpine:edge as s6-builder
# https://github.com/just-containers/s6-overlay/releases
ARG S6_OVERLAY_VERSION="3.1.6.2"
ARG S6_OVERLAY_ARCH="x86_64"
WORKDIR /root-out

# add s6 overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz

# add s6 optional symlinks
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz

FROM alpine:3.18
# add stash
COPY --from=s6-builder /root-out/ /
# ubuntu environment variables
ENV HOME="/root" \
  TZ="Etc/UTC" \
  LANG="en_US.UTF-8" \
  LANGUAGE="en_US:en" \
  S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0" \
  # stash environment variables
  STASH_PORT="9999" \
  STASH_GENERATED="/data/generated" \
  STASH_CACHE="/data/cache" \
  STASH_METADATA="/config/metadata" \
  STASH_CONFIG_FILE="/config/config.yaml" \
  # python env
  PIP_INSTALL_TARGET="/pip-install"

RUN \
  echo "**** install packages ****" && \
  apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    ffmpeg \
    python3 \
    py3-pip \
    shadow \
    tzdata \
    vips-tools \
    wget && \
  echo "**** create stash user and make our folders ****" && \
  useradd -u 1000 -U -d /config -s /bin/false stash && \
  usermod -G users stash && \
  mkdir -p \
    /app \
    /config \
    /config/.stash \
    /data \
    /defaults && \
  echo "**** cleanup ****"

COPY stash/root/ /
COPY --from=stashapp/stash /usr/bin/stash /app/stash

VOLUME /pip-install

EXPOSE 9999
ENTRYPOINT ["/init"]