# syntax=docker/dockerfile:1

ARG ARCHITECTURE="amd64"

FROM stash-s6:hwaccel-base
COPY stash-files/jellyfin.sources /etc/apt/sources.list.d/jellyfin.sources
RUN \
  echo "**** install jellyfin-ffmpeg ****" && \
    mkdir -p \
      /etc/apt/keyrings && \
    curl -fsSL \
      https://repo.jellyfin.org/jellyfin_team.gpg.key | \
      gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg && \
    sed -i 's@ARCHITECTURE@'"$ARCHITECTURE"'@' /etc/apt/sources.list.d/jellyfin.sources && \
    apt-get update && \
    apt-get install -y \
      jellyfin-ffmpeg && \
  echo "**** linking jellyfin ffmpeg ****" && \
    ln -s \
      /usr/lib/jellyfin-ffmpeg/ffmpeg \
      /usr/bin/ffmpeg && \
    ln -s \
      /usr/lib/jellyfin-ffmpeg/ffprobe \
      /usr/bin/ffprobe && \
  echo "**** cleanup ****" && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf \
      /tmp/* \
      /var/lib/apt/lists/* \
      /var/tmp/* \
      /var/log/*
