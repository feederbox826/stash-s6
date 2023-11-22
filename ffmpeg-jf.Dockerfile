# syntax=docker/dockerfile:1

FROM stash-s6:ffmpeg-base

RUN \
  echo "**** install jellyfin-ffmpeg ****" && \
    mkdir -p \
      /etc/apt/keyrings && \
    curl -fsSL \
      https://repo.jellyfin.org/jellyfin_team.gpg.key | \
      gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg
    cat <<EOF | sudo tee /etc/apt/sources.list.d/jellyfin.sources
      Types: deb
      URIs: https://repo.jellyfin.org/ubuntu
      Suites: jammy
      Components: main
      Architectures: amd64
      Signed-By: /etc/apt/keyrings/jellyfin.gpg
      EOF && \
    apt-get update && \
    apt-get install -y \
      jellyfin-ffmpeg && \
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
