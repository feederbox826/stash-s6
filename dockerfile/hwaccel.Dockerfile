# syntax=docker/dockerfile:1
ARG \
  STASH_TAG="latest" \
  UPSTREAM_STASH="docker.io/stashapp/stash:${STASH_TAG}"
FROM $UPSTREAM_STASH AS stash

FROM docker.io/library/debian:trixie AS jellyfin-setup
COPY ci/jellyfin.sources /etc/apt/sources.list.d/jellyfin.sources
ADD https://repo.jellyfin.org/jellyfin_team.gpg.key /ci/jellyfin_team.gpg.key
RUN \
  echo "**** install build dependencies ****" && \
    apt-get update && \
    apt-get install -y \
      --no-install-recommends \
      gnupg && \
  echo "**** set up jellyfin repos ****" && \
    mkdir -p \
      /etc/apt/keyrings && \
    gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg /ci/jellyfin_team.gpg.key

FROM docker.io/library/python:3.13-slim-trixie AS final
# arguments
ARG \
  DEBIAN_FRONTEND="noninteractive"
# debian environment variables
ENV HOME="/config" \
  USER="stash" \
  STASH_CONFIG_FILE="/config/config.yml" \
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
COPY --from=jellyfin-setup /etc/apt/sources.list.d/jellyfin.sources /etc/apt/sources.list.d/jellyfin.sources
COPY --from=jellyfin-setup /etc/apt/keyrings/jellyfin.gpg /etc/apt/keyrings/jellyfin.gpg
RUN \
  echo "**** add contrib and non-free to sources ****" && \
    sed -i 's/main/main contrib non-free/g' /etc/apt/sources.list.d/debian.sources && \
  echo "**** install packages ****" && \
    apt-get update -qq && \
    apt-get install -y \
      --no-install-recommends \
      --no-install-suggests \
      ca-certificates \
      curl \
      jellyfin-ffmpeg7 \
      libvips-tools \
      locales \
      nano \
      tzdata \
      wget && \
  echo "**** install non-free drivers and intel compute runtime ****" && \
    if [ "$( dpkg --print-architecture )" = "amd64" ]; then \
      apt-get install -y \
        --no-install-recommends \
        i965-va-driver-shaders \
        intel-media-va-driver-non-free; \
    fi && \
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
    /usr/bin/uv-pip \
    /opt/uv-pip && \
  ln -s \
    /usr/bin/uv-py \
    /opt/uv-py && \
  echo "**** generate locale ****" && \
    locale-gen en_US.UTF-8
RUN \
  echo "**** create stash user and make our folders ****" && \
  groupadd -g 911 stash && \
  useradd -u 911 -d /config -s /bin/false -r -g stash -G video stash && \
  chage -d 0 stash && \
  mkdir -p \
    /config \
    /defaults

COPY stash/root/ /
VOLUME /pip-install

# arguments
ARG \
  BUILD_DATE \
  SHORT_BUILD_DATE \
  GITHASH \
  OFFICIAL_BUILD="false"
ENV \
  STASH_S6_VARIANT="hwaccel" \
  STASH_S6_BUILD_DATE=$SHORT_BUILD_DATE \
  STASH_S6_GITHASH=$GITHASH \
  NVIDIA_VISIBLE_DEVICES="all" \
  NVIDIA_DRIVER_CAPABILITIES="video" \
  STASH_HW_TEST_TIMEOUT=10
# labels
LABEL \
  org.opencontainers.image.created=$BUILD_DATE \
  org.opencontainers.image.revision=$GITHASH \
  org.opencontainers.image.description="stashapp/stash container with hwaccel, py and user switching" \
  org.opencontainers.image.source=https://github.com/feederbox826/stash-s6 \
  org.opencontainers.image.vendor=feederbox826 \
  org.opencontainers.image.licenses=AGPL-3.0-only
WORKDIR /config
EXPOSE 9999
HEALTHCHECK --start-period=30s CMD curl -sf http://localhost:${STASH_PORT:-9999}/healthz
CMD ["/bin/bash", "/opt/entrypoint.sh"]