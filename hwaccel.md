## hwaccel setup
# CUDA
input args:
`-hwaccel`
`-cuda`
output args:
# NVENC
# QSV
# VA-API
## intel
input args:
`-hwaccel`
`vaapi`
`-hwaccel_device`
`/dev/dri/renderD128`
optional:
`chmod 666 /dev/dri/*`
