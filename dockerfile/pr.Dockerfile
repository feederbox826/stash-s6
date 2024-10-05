# syntax=docker/dockerfile:1
ARG UPSTREAM_TYPE="alpine"

# pull in builds from artifacts
FROM node:alpine AS puller
ARG TARGET_BRANCH \
  TARGET_REPO="stashapp/stash" \
  WORKFLOW_NAME="Build" \
  ARTIFACT_NAME="stash-linux"
WORKDIR /app
COPY ci/parser.mjs parser.mjs
RUN --mount=type=secret,id=GITHUB_TOKEN \
  npm i axios && node parser.mjs

# pull in prebuilt alpine/hwaccel
FROM ghcr.io/feederbox826/stash-s6:${UPSTREAM_TYPE} AS stash
COPY --from=puller /app/stash-linux /app/stash