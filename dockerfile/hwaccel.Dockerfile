# syntax=docker/dockerfile:1
ARG \
  STASH_TAG="latest" \
  UPSTREAM_STASH="stashapp/stash:${STASH_TAG}" \
  UV_VERSION="0.4.6"
FROM $UPSTREAM_STASH AS stash

FROM debian:bookworm-slim AS uv
ARG UV_VERSION
ENV UV_INSTALL_DIR="/bin"
ADD https://astral.sh/uv/${UV_VERSION}/install.sh /install.sh
RUN apt update && \
  apt install -y wget && \
  sh /install.sh
RUN ls -lah /bin/bin/uv

FROM debian:bookworm-slim AS final

# arguments
ARG \
  BUILD_DATE \
  GITHASH \
  STASH_VERSION \
  OFFICIAL_BUILD="false" \
  DEBIAN_FRONTEND="noninteractive" \
  TARGETPLATFORM \
  FFMPEG_VERSION=6 \
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
COPY --from=uv --chmod=755 /bin/bin/uv /usr/bin/uv
RUN \
  echo "**** install build dependencies ****" && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
      --no-install-recommends \
      --no-install-suggests \
      ca-certificates \
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
  echo "**** update and install packages ****" && \
    apt-get update && \
    apt-get install -y \
      --no-install-recommends \
      --no-install-suggests \
      gcc \
      gosu \
      jellyfin-ffmpeg${FFMPEG_VERSION} \
      libc-dev \
      libvips-tools \
      locales \
      nano \
      ncdu \
      python3 \
      ruby \
      tzdata \
      wget \
      yq && \
  echo "**** install non-free drivers and intel compute runtime ****" &&\
    bash /defaults/intel-drivers.sh && \
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
      /usr/sbin/gosu \
      /sbin/su-exec && \
    ln -s \
      /usr/bin/python3 \
      /usr/bin/python && \
  echo "**** generate locale ****" && \
    locale-gen en_US.UTF-8 && \
  echo "**** install ruby gems ****" && \
    gem install \
      faraday && \
  echo "**** create stash user and make our folders ****" && \
    useradd -u 1000 -U -d /config -s /bin/bash stash && \
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

WORKDIR /config
EXPOSE 9999
CMD ["/bin/bash", "/opt/entrypoint.sh"]