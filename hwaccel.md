## hwaccel setup
# CUDA/ NVENC
input args:
`-hwaccel`
`cuda`
output args:
# QSV
# VA-API
## intel
input args:
`-hwaccel`
`vaapi`
optional:
`chmod 666 /dev/dri/*`
