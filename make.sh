#!/bin/sh

prefix=trussio

incus_version=7.0.0
lxc_version=7.0.0
nebula_version=1.10.3

#incus_version=6.23.0
#lxc_version=6.0.6
#nebula_version=1.10.3

#nebula_arch=arm64
#build_arch=arm-native

nebula_arch=amd64
build_arch=x86-compat

docker context use colima-$build_arch

sed -e s/{{INCUS_VERSION}}/$incus_version/g \
    -e s/{{LXC_VERSION}}/$lxc_version/g \
    -e s/{{NEBULA_ARCH}}/$nebula_arch/g \
    -e s/{{PREFIX}}/$prefix/g \
    -e s/{{NEBULA_VERSION}}/$nebula_version/g  < Dockerfile.proto > Dockerfile

docker build -t uek10-incus:lxc${lxc_version}_inc${incus_version} .

docker run -v `pwd`:/b/ -t uek10-incus:lxc${lxc_version}_inc${incus_version}  sh -c  'cp /tmp/*rpm /b/'

rm Dockerfile
