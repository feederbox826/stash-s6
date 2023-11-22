# syntax=docker/dockerfile:1

FROM alpine:3.18
# OS environment variables
ENV HOME="/root" \
  TZ="Etc/UTC" \
  LANG="en_US.UTF-8" \
  LANGUAGE="en_US:en" \
  S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0" \
  S6_VERBOSITY="1" \
  # stash environment variables
  STASH_PORT="9999" \
  STASH_GENERATED="/generated/generated" \
  STASH_CACHE="/generated/cache" \
  STASH_CONFIG_FILE="/config/config.yaml" \
  # python env
  PIP_INSTALL_TARGET="/pip-install" \
  PIP_CACHE_DIR="/pip-install/cache" \
  PYTHONPATH=${PIP_INSTALL_TARGET}

RUN \
  echo "**** install packages ****" && \
  apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    ffmpeg \
    python3 \
    py3-pip \
    s6-overlay \
    shadow \
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

COPY stash/root/ /
# add stash
COPY --from=stashapp/stash /usr/bin/stash /app/stash

VOLUME /pip-install

EXPOSE 9999
ENTRYPOINT ["/init"]