# syntax=docker/dockerfile:1

FROM alpine:3
# OS environment variables
ENV HOME="/root" \
  TZ="Etc/UTC" \
  LANG="en_US.UTF-8" \
  LANGUAGE="en_US:en" \
  # stash environment variables
  STASH_PORT="9999" \
  STASH_GENERATED="/config/generated" \
  STASH_CACHE="/config/cache" \
  STASH_CONFIG_FILE="/config/config.yml" \
  # python env
  PIP_INSTALL_TARGET="/pip-install" \
  PIP_CACHE_DIR="/pip-install/cache" \
  PYTHONPATH=${PIP_INSTALL_TARGET} \
  # hardware acceleration env
  SKIP_NVIDIA_PATCH="true"

VOLUME /pip-install

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
    su-exec \
    tzdata \
    vips-tools \
    wget \
    yq && \
  echo "**** create stash user and make our folders ****" && \
  useradd -u 1000 -U -d /config -s /bin/false stash && \
  usermod -G users stash && \
  mkdir -p \
    /app \
    /config \
    /defaults && \
  echo "**** cleanup ****"

COPY --chmod=755 stash/root/ /
# add stash
COPY --from=stashapp/stash --chmod=755 /usr/bin/stash /app/stash

EXPOSE 9999
CMD ["/bin/ash", "/opt/entrypoint.sh"]