# Build Frontend
FROM node:alpine as frontend
RUN apk add --no-cache make git
ARG GITHASH \
    STASH_VERSION
# mutable steps
WORKDIR /stash
COPY Makefile /stash/
COPY ./graphql ./ui /stash/
RUN make pre-ui && \
    make generate-ui && \
    BUILD_DATE=$(date +"%Y-%m-%d %H:%M:%S") make ui

# Build Backend
FROM golang:1.19-alpine as backend
RUN apk add --no-cache make alpine-sdk
ARG GITHASH \
    STASH_VERSION
# mutable steps
WORKDIR /stash
COPY ./go* ./*.go Makefile gqlgen.yml .gqlgenc.yml /stash/
COPY ./scripts ./pkg ./cmd ./internal \
    /stash/
COPY --from=frontend /stash /stash/
RUN make generate-backend && \
    make flags-release flags-pie stash

# Final Runnable Image
FROM alpine:latest
COPY --from=backend /stash/stash /usr/bin/