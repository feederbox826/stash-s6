# syntax=docker/dockerfile:1
ARG \
  STASH_TAG="latest" \
  UPSTREAM_STASH="docker.io/stashapp/stash:${STASH_TAG}"
FROM $UPSTREAM_STASH AS stash

FROM docker.io/library/alpine:3.22 AS final
ARG TARGETPLATFORM
# OS environment variables
ENV HOME="/config" \
  TZ="Etc/UTC" \
  USER="stash" \
  STASH_CONFIG_FILE="/config/config.yml" \
  # python env
  UV_TARGET="/pip-install/install" \
  PYTHONPATH="/pip-install/install" \
  UV_CACHE_DIR="/pip-install/cache" \
  UV_BREAK_SYSTEM_PACKAGES=1 \
  # hardware acceleration env
  HWACCEL="Jellyfin-ffmpeg" \
  # Logging
  LOGGER_LEVEL="1"
COPY --from=stash --chmod=755 /usr/bin/stash /app/stash
COPY --from=ghcr.io/feederbox826/dropprs:latest /dropprs /bin/dropprs
RUN \
  echo "**** install base packages ****" && \
  apk add --no-cache --no-progress \
    bash \
    curl \
    libva-utils \
    python3 \
    nano \
    shadow \
    wget \
    yq-go
RUN \
  echo "**** install packages ****" && \
  apk add --no-cache --no-progress \
    ca-certificates \
    jellyfin-ffmpeg \
    tzdata \
    uv \
    vips-tools
RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
  echo "**** install optional x86 drivers ****" && \
    apk add --no-cache --no-progress \
      intel-media-driver \
      intel-media-sdk \
      libva-intel-driver && \
    apk add --no-cache --no-progress \
      --repository https://dl-cdn.alpinelinux.org/alpine/edge/testing \
      onevpl-intel-gpu ; \
  fi
RUN \
  echo "**** symlink uv-pip ****" && \
  ln -s \
    /usr/bin/uv-pip \
    /usr/bin/pip && \
  ln -s \
    /usr/bin/uv-pip \
    /opt/uv-pip && \
  ln -s \
    /usr/bin/uv-py \
    /opt/uv-py && \
  echo "**** symlink ffmpeg ****" && \
  ln -s \
    /usr/lib/jellyfin-ffmpeg/ffmpeg \
    /usr/bin/ffmpeg && \
  ln -s \
    /usr/lib/jellyfin-ffmpeg/ffprobe \
    /usr/bin/ffprobe && \
  echo "**** create stash user and make our folders ****" && \
  groupadd -g 911 stash && \
  useradd -u 911 -d /config -s /bin/sh -r -g stash -G video stash && \
  chage -d 0 stash && \
  mkdir -p \
    /config \
    /defaults

COPY stash/root/ /
VOLUME /pip-install

# labels
ARG \
  BUILD_DATE \
  SHORT_BUILD_DATE \
  GITHASH \
  OFFICIAL_BUILD="false"
ENV \
  STASH_S6_VARIANT="hwaccel-alpine" \
  STASH_S6_BUILD_DATE=$SHORT_BUILD_DATE \
  STASH_S6_GITHASH=$GITHASH
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