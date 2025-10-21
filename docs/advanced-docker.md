# setuid / rootless

Running stash-s6 as a specific UID/GID can be accomplished in 2 ways
## environment PUID/ PGID/ AVGID
This is the more widly used way, the container still starts with rootful permissions but dropped with [dropprs](https://github.com/feederbox826/dropprs). User is set via environment variables. user/ group_add will override this.

eg: running as user 1000, group 2000, with additional group 3000
```
services:
  stash:
   ...
    environment:
      - PUID=1000
      - PGID=2000
      - AVGID=3000
```

### user/ group_add
This is the much less common way and used mostly in rootless deployments or for additional security. The container **never** has root access and permissions need to be updated outside of the container to be respected. Using this, PUID/PGID environment varibles **cannot** be honored

eg: running as user 1000, group 2000 with additioal group 3000
```
services:
  stash:
   ...
    user: 1000:2000
    group_add:
      - 3000
```

# read_only
In rare cares or when additional security is desired, stashapp_stash can be run in read_only mode. This prevents any modifications to the filesystem outside of mounted paths. This does break inevitably break a few features. In order to use this, all paths under config **must** be mounted to a volume.

## Completely Broken:
- `CUSTOM_CERT_PATH`
  - update-ca-certificates is ran on-demand, unless you want to manually bundle into the filesystem

## uv /tmp workaround
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