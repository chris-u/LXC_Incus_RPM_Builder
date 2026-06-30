#!/bin/sh

prefix=trussio

incus_version=7.2.0
lxc_version=7.0.0
nebula_version=1.10.3

arch=arm

case $arch
in
  x86) 
      nebula_arch=amd64 
      build_arch=x86-compat
    ;;
  arm) 
      nebula_arch=arm64
      build_arch=arm-native
    ;;
esac
    

docker context use colima-$build_arch

docker build \
  --build-arg LXC_VERSION="$lxc_version" \
  --build-arg INCUS_VERSION="$incus_version" \
  --build-arg PREFIX="$prefix" \
  --build-arg NEBULA_ARCH="$nebula_arch" \
  --build-arg NEBULA_VERSION="$nebula_version" \
  -t uek10-incus:lxc${lxc_version}_inc${incus_version} \
  .
  


docker run -v `pwd`:/b/ -t uek10-incus:lxc${lxc_version}_inc${incus_version}  sh -c  'cp /tmp/*rpm /b/'

