# syntax=docker/dockerfile:1

ARG UPSTREAM_IMAGE="docker.io/library/stash-s6"
FROM ${UPSTREAM_IMAGE}:hwaccel-base
ENV HWACCEL="Debian-ffmpeg"
RUN \
  echo "**** add non-free to sources ****" && \
    sed -i \
      's/main contrib/main contrib non-free non-free-firmware/g' \
      /etc/apt/sources.list.d/debian.sources && \
  echo "**** install debian ffmpeg ****" && \
    apt-get update && \
    apt-get install -y \
      --no-install-recommends \
      --no-install-suggests \
      ffmpeg \
      libcuda1
      libnvcuvid1
      libnvidia-encode1
      opencl-icd
      va-driver-all
      vdpau-driver-all && \
  echo "**** cleanup ****" && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf \
      /tmp/* \
      /var/lib/apt/lists/* \
      /var/tmp/* \
      /var/log/*
