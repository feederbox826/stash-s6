# syntax=docker/dockerfile:1
ARG \
  STASH_TAG="latest" \
  UPSTREAM_STASH="docker.io/stashapp/stash:${STASH_TAG}"
FROM $UPSTREAM_STASH AS stash

FROM docker.io/library/alpine:3.22 AS final
# OS environment variables
ENV HOME="/config" \
  TZ="Etc/UTC" \
  USER="stash" \
  # python env
  UV_TARGET="/pip-install/install" \
  PYTHONPATH="/pip-install/install" \
  UV_CACHE_DIR="/pip-install/cache" \
  UV_BREAK_SYSTEM_PACKAGES=1 \
  # hardware acceleration env
  HWACCEL="NONE" \
  SKIP_NVIDIA_PATCH="true" \
  # Logging
  LOGGER_LEVEL="1"
COPY --from=stash --chmod=755 /usr/bin/stash /app/stash
COPY --from=ghcr.io/feederbox826/dropprs:latest /dropprs /bin/dropprs
RUN \
  echo "**** install packages ****" && \
  apk add --no-cache --no-progress \
    bash \
    ca-certificates \
    curl \
    ffmpeg \
    python3 \
    nano \
    ncdu \
    shadow \
    tzdata \
    uv \
    vips-tools \
    wget \
    yq-go
RUN \
  echo "**** symlink uv-pip ****" && \
  ln -s \
    /opt/uv-pip \
    /usr/bin/pip && \
  echo "**** create stash user and make our folders ****" && \
  groupadd -g 911 stash && \
  useradd -u 911 -d /config -s /bin/sh -r -g stash stash && \
  mkdir -p \
    /config \
    /defaults

COPY stash/root/ /
VOLUME /pip-install

# dynamic labels
ARG \
  BUILD_DATE \
  SHORT_BUILD_DATE \
  GITHASH \
  OFFICIAL_BUILD="false"
ENV \
  STASH_S6_VARIANT="alpine" \
  STASH_S6_BUILD_DATE=$SHORT_BUILD_DATE \
  STASH_S6_GITHASH=$GITHASH
LABEL \
  org.opencontainers.image.created=$BUILD_DATE \
  org.opencontainers.image.revision=$GITHASH \
  org.opencontainers.image.source=https://feederbox.cc/gh/stash-s6 \
  org.opencontainers.image.vendor=feederbox826 \
  org.opencontainers.image.licenses=AGPL-3.0-only
WORKDIR /config
EXPOSE 9999
HEALTHCHECK --start-period=30s CMD curl -sf http://localhost:${STASH_PORT:-9999}/healthz
CMD ["/bin/bash", "/opt/entrypoint.sh"]