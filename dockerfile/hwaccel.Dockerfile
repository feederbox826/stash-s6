# syntax=docker/dockerfile:1
ARG \
  STASH_TAG="latest" \
  UPSTREAM_STASH="stashapp/stash:${STASH_TAG}"
FROM $UPSTREAM_STASH AS stash

FROM python:3.13-slim-bookworm AS final

# arguments
ARG \
  BUILD_DATE \
  GITHASH \
  STASH_VERSION \
  OFFICIAL_BUILD="false" \
  DEBIAN_FRONTEND="noninteractive" \
  TARGETPLATFORM \
  FFMPEG_VERSION=7 \
  STASH_TAG="latest"
# labels
LABEL \
  org.opencontainers.image.created=$BUILD_DATE \
  org.opencontainers.image.revision=$GITHASH \
  org.opencontainers.image.version=$STASH_VERSION \
  org.opencontainers.image.source=https://feederbox.cc/gh/stash-s6 \
  org.opencontainers.image.vendor=feederbox826 \
  org.opencontainers.image.licenses=AGPL-3.0-only \
  official_build=$OFFICIAL_BUILD \
  UPSTREAM_STASH="stashapp/stash:${STASH_TAG}"
# environment variables
# debian environment variables
ENV HOME="/config" \
  TZ="Etc/UTC" \
  LANG="en_US.UTF-8" \
  LANGUAGE="en_US:en" \
  # stash environment variables
  STASH_CONFIG_FILE="/config/config.yml" \
  USER="stash" \
  # python env
  UV_TARGET="/pip-install/install" \
  PYTHONPATH="/pip-install/install" \
  UV_CACHE_DIR="/pip-install/cache" \
  UV_BREAK_SYSTEM_PACKAGES=1 \
  # hardware acceleration env
  HWACCEL="Jellyfin-ffmpeg" \
  NVIDIA_DRIVER_CAPABILITIES="compute,video,utility" \
  NVIDIA_VISIBLE_DEVICES="all" \
  # Logging
  LOGGER_LEVEL="1"

# copy over build files
COPY stash/root/defaults /defaults
COPY --from=stash --chmod=755 /usr/bin/stash /app/stash
COPY --from=ghcr.io/astral-sh/uv:latest --chmod=755 /uv /bin/uv
COPY --from=docker.io/mikefarah/yq /usr/bin/yq /usr/bin/yq
COPY --from=ghcr.io/feederbox826/dropprs:latest /dropprs /bin/dropprs
RUN \
  echo "**** install build dependencies ****" && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
      --no-install-recommends \
      --no-install-suggests \
      curl \
      gnupg && \
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
    sed -i \
      "s/ARCHITECTURE/$( dpkg --print-architecture )/" \
      "/etc/apt/sources.list.d/jellyfin.sources" && \
  echo "**** install packages ****" && \
    apt-get update && \
    apt-get install -y \
      --no-install-recommends \
      --no-install-suggests \
      jellyfin-ffmpeg${FFMPEG_VERSION} \
      libvips-tools \
      locales \
      nano \
      ncdu \
      ruby \
      tzdata \
      wget && \
  echo "**** install non-free drivers and intel compute runtime ****" && \
    bash /defaults/intel-drivers.sh && \
  echo "**** cleanup ****" && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf \
      /tmp/* \
      /var/lib/apt/lists/* \
      /var/tmp/* \
      /var/log/*
RUN \
  echo "**** symlink packages ****" && \
  ln -s \
    /usr/lib/jellyfin-ffmpeg/ffmpeg \
    /usr/bin/ffmpeg && \
  ln -s \
    /usr/lib/jellyfin-ffmpeg/ffprobe \
    /usr/bin/ffprobe && \
  ln -s \
    /usr/lib/jellyfin-ffmpeg/vainfo \
    /usr/bin/vainfo && \
  ln -s \
    /opt/uv-pip \
    /usr/bin/pip && \
  echo "**** generate locale ****" && \
    locale-gen en_US.UTF-8 && \
  echo "**** install ruby gems ****" && \
    gem install \
      faraday
RUN \
  echo "**** create stash user and make our folders ****" && \
  useradd -u 911 -U -d /config -s /bin/bash stash && \
  usermod -G users stash && \
  usermod -G video stash && \
  mkdir -p \
    /config \
    /defaults

COPY stash/root/ /
VOLUME /pip-install

WORKDIR /config
EXPOSE 9999
CMD ["/bin/bash", "/opt/entrypoint.sh"]