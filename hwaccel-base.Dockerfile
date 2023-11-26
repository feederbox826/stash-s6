# syntax=docker/dockerfile:1

FROM debian:bookworm
ARG DEBIAN_FRONTEND="noninteractive"
# debian environment variables
ENV HOME="/root" \
  TZ="Etc/UTC" \
  LANG="en_US.UTF-8" \
  LANGUAGE="en_US:en" \
  # stash environment variables
  STASH_CONFIG_FILE="/config/config.yml" \
  USER="stash" \
  # python env
  PIP_INSTALL_TARGET="/pip-install" \
  PIP_CACHE_DIR="/pip-install/cache" \
  PYTHONPATH=${PIP_INSTALL_TARGET} \
  # hardware acceleration env
  HWACCEL="NONE" \
  LIBVA_DRIVERS_PATH="/usr/local/lib/x86_64-linux-gnu/dri" \
  NVIDIA_DRIVER_CAPABILITIES="compute,video,utility" \
  NVIDIA_VISIBLE_DEVICES="all" \
  # Logging
  LOGGER_LEVEL="1"

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
      gosu \
      libvips-tools \
      python3 \
      python3-pip \
      tzdata \
      wget \
      yq && \
  echo "**** link su-exec to gosu ****" && \
    ln -s /usr/sbin/gosu /sbin/su-exec && \
  echo "**** generate locale ****" && \
    locale-gen en_US.UTF-8 && \
  echo "**** create stash user and make our folders ****" && \
    useradd -u 1000 -U -d /config -s /bin/false stash && \
    usermod -G users stash && \
    mkdir -p \
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
COPY --from=stashapp/stash --chmod=755 /usr/bin/stash /app/stash

VOLUME /pip-install

EXPOSE 9999
CMD ["/bin/bash", "/opt/entrypoint.sh"]