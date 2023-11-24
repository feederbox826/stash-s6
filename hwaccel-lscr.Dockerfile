# syntax=docker/dockerfile:1
ARG UPSTREAM_IMAGE="docker.io/library/stash-s6"

# take libraries from linuxserver/ffmpeg
FROM ghcr.io/linuxserver/ffmpeg as lscr-ffmpeg

# copy and build
FROM ${UPSTREAM_IMAGE}:hwaccel-base
ENV HWACCEL="LinuxServer-ffmpeg"
COPY --from=lscr-ffmpeg /usr/local/bin /usr/local/bin
COPY --from=lscr-ffmpeg /usr/local/lib /usr/local/lib
COPY --from=lscr-ffmpeg /etc/OpenCL/vendors /etc/OpenCL/vendors
RUN \
  echo "**** installling runtime dependencies ****" && \
    apt-get update && \
    apt-get install -y \
      libexpat1 \
      libglib2.0-0 \
      libgomp1 \
      libharfbuzz0b \
      libpciaccess0 \
      libv4l-0 \
      libwayland-client0 \
      libx11-6 \
      libx11-xcb1 \
      libxcb-dri3-0 \
      libxcb-shape0 \
      libxcb-xfixes0 \
      libxcb1 \
      libxext6 \
      libxfixes3 \
      libxml2 \
      ocl-icd-libopencl1 && \
  echo "**** cleanup ****" && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf \
      /tmp/* \
      /var/lib/apt/lists/* \
      /var/tmp/* \
      /var/log/*