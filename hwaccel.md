# HWAccel arguments

# CUDA/ NVENC
input args:  
`-hwaccel`  
`cuda`  
output args:  
none  
# QSV
input args:  
`-hwaccel`  
`vaapi`  
optional:  
`chmod 666 /dev/dri/*`  
# VA-API
## intel
input args:  
`-hwaccel`  
`vaapi`  
output args:  
none  
optional:  
`chmod 666 /dev/dri/*`  

env variables for g5-8
```
LIBVA_DRIVER_NAME_JELLYFIN=i965
LIBVA_DRIVER_NAME=i965
```