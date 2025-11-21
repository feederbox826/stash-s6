# setup
On Linux🐧, make sure the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) is installed

On Windows 🪟, make sure that:
- [NVIDIA drivers](https://www.nvidia.com/drivers/) are up to date
- [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) is installed and up to date (`wsl --update`)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) is up to date

add the following snippets to your `docker-compose.yml`
```yml
x-nvenc: &nvenc
  runtime: nvidia
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: 1
            capabilities: [gpu]

services:
  stash:
    <<: *nvenc
    ...
```

- [docker compose - gpu support](https://docs.docker.com/compose/how-tos/gpu-support/)
- [docker desktop - GPU](https://docs.docker.com/desktop/features/gpu/)