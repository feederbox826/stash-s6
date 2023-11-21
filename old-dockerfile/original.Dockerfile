FROM alpine:latest
COPY --from=stashapp/stash /usr/bin/stash /usr/bin/

RUN apk add --no-cache \
        ca-certificates vips-tools ffmpeg python3 py3-pip && \
    pip3 install \
        requests \
        bs4 \
        lxml \
        pystashlib \
        stashapp-tools

ENV STASH_CONFIG_FILE=/root/.stash/config.yml
EXPOSE 9999
ENTRYPOINT ["stash"]
