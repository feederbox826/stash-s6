# syntax=docker/dockerfile:1
ARG \
  STASH_TAG="latest" \
  UPSTREAM_STASH="stashapp/stash:${STASH_TAG}" \
  UV_VERSION="0.4.6"
FROM $UPSTREAM_STASH AS stash

FROM alpine:3 AS uv
ENV UV_INSTALL_DIR="/bin"
ADD https://astral.sh/uv/${UV_VERSION}/install.sh /install.sh
RUN sh /install.sh && \
  mv /bin/bin/uv /uv

FROM alpine:3.20 AS final

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
  org.opencontainers.image.source=https://feederbox.cc/gh/stash-s6 \
  org.opencontainers.image.vendor=feederbox826 \
  org.opencontainers.image.licenses=AGPL-3.0-only \
  official_build=$OFFICIAL_BUILD \
  STASH_TAG="latest"
# OS environment variables
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
  HWACCEL="NONE" \
  SKIP_NVIDIA_PATCH="true" \
  # Logging
  LOGGER_LEVEL="1"
COPY --from=stash --chmod=755 /usr/bin/stash /app/stash
COPY --from=uv --chmod=755 /uv /bin/uv
RUN \
  echo "**** install packages ****" && \
  apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    ffmpeg \
    gcc \
    python3 \
    python3-dev \
    musl-dev \
    nano \
    ncdu \
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

WORKDIR /config
EXPOSE 9999
CMD ["/bin/bash", "/opt/entrypoint.sh"]