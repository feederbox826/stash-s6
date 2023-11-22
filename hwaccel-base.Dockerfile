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
# add nvenc patch
ADD --chmod=0755 https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch.sh /root-out/usr/local/bin/

FROM debian:bookworm
# add stash
COPY --from=stashapp/stash /usr/bin/stash /app/stash
COPY --from=s6-builder /root-out/ /
ARG DEBIAN_FRONTEND="noninteractive"
# debian environment variables
ENV HOME="/root" \
  TZ="Etc/UTC" \
  LANG="en_US.UTF-8" \
  LANGUAGE="en_US:en" \
  S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0" \
  # stash environment variables
  STASH_PORT="9999" \
  STASH_GENERATED="/generated/generated" \
  STASH_CACHE="/generated/cache" \
  STASH_METADATA="/config/metadata" \
  STASH_CONFIG_FILE="/config/config.yaml" \
  # python env
  PIP_INSTALL_TARGET="/pip-install" \
  PYTHONPATH=${PIP_INSTALL_TARGET} \
  # hardware acceleration env
  LIBVA_DRIVERS_PATH="/usr/local/lib/x86_64-linux-gnu/dri" \
  NVIDIA_DRIVER_CAPABILITIES="compute,video,utility" \
  NVIDIA_VISIBLE_DEVICES="all"

RUN \
  echo "**** add contrib to sources ****" && \
    sed -i 's/main/main contrib/g' /etc/apt/sources.list.d/debian.sources && \
  echo "**** install apt-utils and locales ****" && \
    apt-get update && \
    apt-get install -y \
      apt-utils \
      locales && \
  echo "**** install packages ****" && \
    apt-get install -y \
      --no-install-recommends \
      --no-install-suggests \
      ca-certificates \
      curl \
      gnupg \
      libvips-tools \
      python3 \
      python3-pip \
      tzdata \
      wget && \
  echo "**** generate locale ****" && \
    locale-gen en_US.UTF-8 && \
  echo "**** create stash user and make our folders ****" && \
    useradd -u 1000 -U -d /config -s /bin/false stash && \
    usermod -G users stash && \
    mkdir -p \
      /app \
      /config \
      /defaults && \
  echo "**** cleanup ****" && \
    apt-get autoremove && \
    apt-get clean && \
    rm -rf \
      /tmp/* \
      /var/lib/apt/lists/* \
      /var/tmp/* \
      /var/log/*

COPY stash/root/ /
COPY stash-hwaccel/root/ /

EXPOSE 9999
ENTRYPOINT ["/init"]