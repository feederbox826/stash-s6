# stashapp/stash with s6

for [stashapp/stash#4300](https://github.com/stashapp/stash/issues/4300)

## alpine
- built on alpine linux, no hardware acceleration support
```
docker pull ghcr.io/feederbox826/stash-s6:alpine
```

## cuda
- built on ubuntu, hardware acceration support via ffmpeg
```
docker pull ghcr.io/feederbox826/stash-s6:cuda
```