# syntax=docker/dockerfile:1
ARG \
  STASH_TAG="latest" \
  UPSTREAM_STASH="stashapp/stash:${STASH_TAG}"
FROM $UPSTREAM_STASH as stash

FROM alpine:3.20 as final

# labels
ARG \
  BUILD_DATE \
  GITHASH \
  STASH_VERSION \
  OFFICIAL_BUILD="false"
LABEL \
  org.opencontainers.image.created=$BUILD_DATE \
  org.opencontainers.image.revision=$GITHASH \
  org.opencontainers.image.version=$STASH_VERSION \
  official_build=$OFFICIAL_BUILD\
  STASH_TAG="latest"
# OS environment variables
ENV HOME="/root" \
  TZ="Etc/UTC" \
  LANG="en_US.UTF-8" \
  LANGUAGE="en_US:en" \
  # stash environment variables
  STASH_CONFIG_FILE="/config/config.yml" \
  USER="stash" \
  # python env
  PIP_TARGET="/pip-install/install" \
  PYTHONPATH="/pip-install/install" \
  PIP_CACHE_DIR="/pip-install/cache" \
  PIP_BREAK_SYSTEM_PACKAGES=1 \
  # hardware acceleration env
  HWACCEL="NONE" \
  SKIP_NVIDIA_PATCH="true" \
  # Logging
  LOGGER_LEVEL="1"
COPY --from=stash --chmod=755 /usr/bin/stash /app/stash
RUN \
  echo "**** install packages ****" && \
  apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    ffmpeg \
    python3 \
    py3-pip \
    ruby \
    shadow \
    su-exec \
    tzdata \
    vips-tools \
    wget \
    yq-go && \
  echo "**** install ruby gems ****" && \
    gem install \
      faraday && \
  echo "**** create stash user and make our folders ****" && \
  useradd -u 1000 -U -d /config -s /bin/false stash && \
  usermod -G users stash && \
  mkdir -p \
    /config \
    /defaults && \
  echo "**** cleanup ****"

COPY stash/root/ /

VOLUME /pip-install

EXPOSE 9999
CMD ["/bin/bash", "/opt/entrypoint.sh"]