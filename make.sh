#!/bin/sh

incus_version=6.23.0
lxc_version=6.0.6

sed -e s/{{INCUS_VERSION}}/$incus_version/g -e s/{{LXC_VERSION}}/$lxc_version/g < Dockerfile.proto > Dockerfile

docker build -t uek10-incus:lxc${lxc_version}_inc${incus_version} .

docker run -v `pwd`:/b/ -t uek10-incus:lxc${lxc_version}_inc${incus_version}  sh -c  'cp /tmp/*rpm /b/'

rm Dockerfile
