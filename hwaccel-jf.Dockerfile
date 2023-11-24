# syntax=docker/dockerfile:1

ARG UPSTREAM_IMAGE="docker.io/library/stash-s6"
FROM ${UPSTREAM_IMAGE}:hwaccel-base

ENV HWACCEL="Jellyfin-ffmpeg"
ARG ARCHITECTURE="amd64"

COPY stash-files/jellyfin.sources /etc/apt/sources.list.d/jellyfin.sources
RUN \
  echo "**** install jellyfin-ffmpeg ****" && \
    mkdir -p \
      /etc/apt/keyrings && \
    curl -fsSL \
      https://repo.jellyfin.org/jellyfin_team.gpg.key | \
      gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg && \
    sed -i -r "s/ARCHITECTURE/$ARCHITECTURE/g" "/etc/apt/sources.list.d/jellyfin.sources" && \
    apt-get update && \
    apt-get install -y \
      jellyfin-ffmpeg6 && \
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
