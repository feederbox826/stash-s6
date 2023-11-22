# syntax=docker/dockerfile:1

FROM stash-s6:hwaccel-base

RUN \
  echo "**** install debian ffmpeg ****" && \
    apt-get update && \
    apt-get install -y \
      ffmpeg && \
  echo "**** cleanup ****" && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf \
      /tmp/* \
      /var/lib/apt/lists/* \
      /var/tmp/* \
      /var/log/*
