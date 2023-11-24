# syntax=docker/dockerfile:1
ARG UPSTREAM_IMAGE="docker.io/library/stash-s6"

# take libraries from linuxserver/ffmpeg
FROM ghcr.io/linuxserver/ffmpeg as lscr-ffmpeg

# copy and build
FROM ${UPSTREAM_IMAGE}:hwaccel-base
ENV HWACCEL="LinuxServer-ffmpeg"
COPY --from=lscr-ffmpeg /usr/local/bin /usr/local/bin
COPY --from=lscr-ffmpeg /usr/local/lib /usr/local/lib
RUN \
  echo "**** installling runtime dependencies ****" && \
    apt-get update && \
    apt-get install -y \
      libexpat1 \
      libfontconfig1 \
      libglib2.0-0 \
      libgomp1 \
      libharfbuzz0b \
      libv4l-0 \
      libx11-6 \
      libxcb1 \
      libxext6 \
      libxml2 && \
  echo "**** cleanup ****" && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf \
      /tmp/* \
      /var/lib/apt/lists/* \
      /var/tmp/* \
      /var/log/*