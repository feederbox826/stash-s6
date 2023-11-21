FROM stashapp/stash as stash

FROM alpine as build
RUN apk add ca-certificates wget
WORKDIR /tmp
RUN mkdir -p \
        /patched-lib && \
    wget -O /tmp/patch.sh \
        https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch.sh && \
    wget -O /tmp/docker-entrypoint.sh \
        https://raw.githubusercontent.com/keylase/nvidia-patch/master/docker-entrypoint.sh && \
    chmod +x \
        /tmp/patch.sh \
        /tmp/docker-entrypoint.sh \

# Final Runnable Image
FROM nvidia/cuda:12.0.1-base-ubuntu22.04

COPY --from=stashapp/stash /usr/bin/stash /usr/bin/
RUN apt update && \
    apt install -y \
        libvips-tools \
        ffmpeg \
        python3-pip && \
    rm -rf /var/lib/apt/lists/*

# NVENC Patch
RUN mkdir -p \
        /usr/local/bin \
        /patched-lib && \
COPY --from=build /tmp /usr/local/bin/

# pip packages
RUN pip3 install \
    requests \
    bs4 \
    lxml \
    pystashlib \
    stashapp-tools

ENV LANG C.UTF-8
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES=video,utility
ENV STASH_CONFIG_FILE=/root/.stash/config.yml
EXPOSE 9999
ENTRYPOINT ["docker-entrypoint.sh", "stash"]
