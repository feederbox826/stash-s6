# syntax=docker/dockerfile:1

ARG UPSTREAM_IMAGE="docker.io/library/stash-s6"
FROM ${UPSTREAM_IMAGE}:hwaccel-base

ENV HWACCEL="Jellyfin-ffmpeg"
ARG ARCHITECTURE="amd64"
ARG COMPUTE_RUNTIME_VERSION="23.30.26918.9"

COPY stash-files/jellyfin.sources /etc/apt/sources.list.d/jellyfin.sources
RUN \
  echo "**** install jellyfin-ffmpeg ****" && \
    sed -i \
      's/main contrib/main contrib non-free non-free-firmware/g' \
      /etc/apt/sources.list.d/debian.sources && \
    mkdir -p \
      /etc/apt/keyrings && \
    curl -fsSL \
      https://repo.jellyfin.org/jellyfin_team.gpg.key | \
      gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg && \
    sed -i -r \
      "s/ARCHITECTURE/$ARCHITECTURE/g" \
      "/etc/apt/sources.list.d/jellyfin.sources" && \
    apt-get update && \
    apt-get install -y \
      jellyfin-ffmpeg6 && \
  echo "**** install intel tools ****" && \
    apt-get install -y \
      --no-install-recommends \
      --no-install-suggests \
        intel-gpu-tools \
        vainfo && \
  echo "**** install intel compute-runtime ****" && \
    cd /tmp && \
    wget https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.14828.8/intel-igc-core_1.0.14828.8_amd64.deb && \
    wget https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.14828.8/intel-igc-opencl_1.0.14828.8_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/${COMPUTE_RUNTIME_VERSION}/intel-level-zero-gpu-dbgsym_1.3.26918.9_amd64.ddeb && \
    wget https://github.com/intel/compute-runtime/releases/download/${COMPUTE_RUNTIME_VERSION}/intel-level-zero-gpu_1.3.26918.9_amd64.deb &&\
    wget https://github.com/intel/compute-runtime/releases/download/${COMPUTE_RUNTIME_VERSION}/intel-opencl-icd-dbgsym_${COMPUTE_RUNTIME_VERSION}_amd64.ddeb && \
    wget https://github.com/intel/compute-runtime/releases/download/${COMPUTE_RUNTIME_VERSION}/intel-opencl-icd_${COMPUTE_RUNTIME_VERSION}_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/${COMPUTE_RUNTIME_VERSION}/libigdgmm12_22.3.0_amd64.deb && \
    dpkg -i *.deb && \
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
