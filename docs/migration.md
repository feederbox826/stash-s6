# stash-s6 migration

> [!WARNING]
> Full migration is not necessary AND not recommended in 99% of cases.

DON'T use MIGRATE if:
- If you are using PUID, PGID (permissions will be adjusted automatically)

DO use MIGRATE if:
- You are too lazy to set permissions in rootless (`user: 1000:1000`)
- You are using anonymous volumes (please switch to bind mounts)
- You want to switch from everything under `/root/.stash` to `/generated`, `/blobs` etc..

## pip-install
`pip-install` is nice to have in a directory you can see and control, but will not cause any conflicts with any other containers. Add the following to your docker-compose
```yml
volumes:
  - ./pip-install:/pip-install
  # OR
  - /data/stash/pip-install:/pip-install
```

## hwaccel switch
- Migration is not necessary in most cases, just switching the image is enough. stash-s6 will run in stashapp/stash mode.

# Migration
## Environment Variables
Keep existing variables like `STASH_GENERATED`, `STASH_CONFIG`. stash-s6 will read, respect and skip migration for these paths.

Add variables like `MIGRATE=TRUE`, `PUID`/`PGID` as desired.

## Paths
- add the new `/config` mount, make sure the path does not overlap with your existing config mount
```yml
- ./new-config:/config
# OR
- /data/new-stash/config:/config
```
- add the new `/pip-install` mount
```yml
- ./pip-install:/pip-install
# OR
- /data/new-stash/pip-install:/pip-install
```

Any existing volumes like `/generated` or `/data` can be safely left alone. These do not need to be migrated and will be ignored.

## Migrating back
Migrating back is mostly making sure all the files are back where stashapp/stash expects them to be. You can do this manually by moving files back to where `/root/.stash` is mounted and editing `config.yml` to point to the existing paths. If you wish to continue running rootless, you can follow the instructions/ tweaks at [notes/rootless.md](https://github.com/feederbox826/notes/blob/main/rootless.md)