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

## user/ group_add
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