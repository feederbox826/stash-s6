# syntax=docker/dockerfile:1

ARG UPSTREAM_IMAGE="docker.io/library/stash:hwaccel-base"
FROM ${UPSTREAM_IMAGE}

ENV HWACCEL="Debian-ffmpeg"
RUN \
  echo "**** install debian ffmpeg ****" && \
    apt-get update && \
    apt-get install -y \
      --no-install-recommends \
      ffmpeg && \
  echo "**** cleanup ****" && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf \
      /tmp/* \
      /var/lib/apt/lists/* \
      /var/tmp/* \
      /var/log/*
