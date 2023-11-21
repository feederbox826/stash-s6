FROM stashapp/stash as stash

FROM ghcr.io/linuxserver/ffmpeg:latest

COPY --from=stashapp/stash /usr/bin/stash /usr/bin/
RUN apt update && \
    apt install -y \
        libvips-tools \
        vainfo \
        python3-pip && \
    rm -rf /var/lib/apt/lists/*

# pip packages
RUN pip3 install \
    requests \
    bs4 \
    lxml \
    pystashlib \
    stashapp-tools

ENV STASH_CONFIG_FILE=/root/.stash/config.yml
EXPOSE 9999
ENTRYPOINT ["stash"]