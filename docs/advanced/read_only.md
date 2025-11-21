# read_only
stash-s6 **can** be ran in `read_only` mode, with a few tweaks needed. This is not the default run mode.

## Completely Broken:
- `CUSTOM_CERT_PATH`
  - update-ca-certificates is ran on-demand, unless manually bundle your certificates into the filesystem

## uv `/tmp` workaround
uv requires writing to `/tmp` when installing dependencies. This can be bypassed by adding a tmpfs mount to the container that runs in RAM. This uses a yaml anchor for reusability

```
x-tmpfs: &tmpfs
  type: tmpfs
  target: /tmp
  tmpfs:
    size: 10485760 # 10M

services:
  stash:
    volumes:
      - << : *tmpfs
```