technology  lscr    jellyfin    base
vaapi g5+   ?       ?           ?
vaapi g8+   ?       ?           ?
qsv         ?       ?           ?
nvenc       ❌       ✅         ❌
v4l2        ?       ?           ?

# notes
- lscr nvenc doesn't support scale-cuda so nvenc_h264 is not loaded
- base nvenv is missing audio for transcodes
