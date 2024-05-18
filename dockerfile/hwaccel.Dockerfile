# syntax=docker/dockerfile:1
FROM debian:bookworm-slim

ARG \
  BUILD_DATE \
  GITHASH \
  STASH_VERSION \
  OFFICIAL_BUILD="false" \
  DEBIAN_FRONTEND="noninteractive" \
  TARGETPLATFORM
# labels
LABEL \
  org.opencontainers.image.created=$BUILD_DATE \
  org.opencontainers.image.revision=$GITHASH \
  org.opencontainers.image.version=$STASH_VERSION \
  official_build=$OFFICIAL_BUILD
# environment variables
# debian environment variables
ENV HOME="/root" \
  TZ="Etc/UTC" \
  LANG="en_US.UTF-8" \
  LANGUAGE="en_US:en" \
  # stash environment variables
  STASH_CONFIG_FILE="/config/config.yml" \
  USER="stash" \
  # python env
  PY_VENV="/pip-install/venv" \
  PIP_CACHE_DIR="/pip-install/cache" \
  PATH="$PY_VENV/bin:$PATH" \
  # hardware acceleration env
  HWACCEL="Jellyfin-ffmpeg" \
  NVIDIA_DRIVER_CAPABILITIES="compute,video,utility" \
  NVIDIA_VISIBLE_DEVICES="all" \
  # Logging
  LOGGER_LEVEL="1"

COPY stash/root/defaults /defaults
COPY --from=stashapp/stash --chmod=755 /usr/bin/stash /app/stash

RUN \
  echo "**** add contrib and non-free to sources ****" && \
    sed -i 's/main/main contrib non-free non-free-firmware/g' /etc/apt/sources.list.d/debian.sources && \
  echo "**** set up jellyfin repos ****" && \
    mkdir -p \
      /etc/apt/keyrings && \
    curl -fsSL \
      https://repo.jellyfin.org/jellyfin_team.gpg.key | \
      gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg && \
    cp \
      /defaults/jellyfin.sources \
      /etc/apt/sources.list.d/jellyfin.sources && \
    sed -i -r \
      "s/ARCHITECTURE/$ARCHITECTURE/g" \
      "/etc/apt/sources.list.d/jellyfin.sources" && \
  echo "**** update and install packages ****" && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
      --no-install-recommends \
      --no-install-suggests \
      apt-utils \
      ca-certificates \
      curl \
      gnupg \
      gosu \
      jellyfin-ffmpeg6 \
      libvips-tools \
      locales \
      python3 \
      python3-pip \
      python3-venv \
      ruby \
      tzdata \
      wget \
      yq && \
  echo "**** install non-free drivers and intel compute runtime ****" &&\
    bash /defaults/intel-drivers.sh && \
  echo "**** linking jellyfin ffmpeg ****" && \
    ln -s \
      /usr/lib/jellyfin-ffmpeg/ffmpeg \
      /usr/bin/ffmpeg && \
    ln -s \
      /usr/lib/jellyfin-ffmpeg/ffprobe \
      /usr/bin/ffprobe && \
    ln -s \
      /usr/lib/jellyfin-ffmpeg/vainfo \
      /usr/bin/vainfo && \
  echo "**** link su-exec to gosu ****" && \
    ln -s /usr/sbin/gosu /sbin/su-exec && \
  echo "**** generate locale ****" && \
    locale-gen en_US.UTF-8 && \
  echo "**** activate python virtual environment ****" && \
    python3 -m venv ${PY_VENV} && \
  echo "**** install ruby gems ****" && \
    gem install \
      faraday && \
  echo "**** create stash user and make our folders ****" && \
    useradd -u 1000 -U -d /config -s /bin/false stash && \
    usermod -G users stash && \
    usermod -G video stash && \
    mkdir -p \
      /config \
      /defaults && \
  echo "**** cleanup ****" && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf \
      /tmp/* \
      /var/lib/apt/lists/* \
      /var/tmp/* \
      /var/log/*

COPY stash/root/ /

VOLUME /pip-install

EXPOSE 9999
CMD ["/bin/bash", "/opt/entrypoint.sh"]