#ARG LXC_VERSION=7.0.0
##ARG INCUS_VERSION=7.0.0
#ARG INCUS_VERSION=6.23.0
#ARG NEBULA_VERSION=1.10.2
#ARG NEBULA_ARCH=arm64
#ARG PREFIX=trussio

FROM  oraclelinux:10 AS OEL10builder

RUN dnf groupinstall 'development tools'

RUN dnf config-manager --enable ol10_codeready_builder

RUN dnf install oracle-epel-release-el10 &&  dnf config-manager --set-enabled ol10_codeready_builder

RUN dnf install oracle-epel-release-el10 golang tcl ruby-devel gem pip cmake autoconf automake tar\
                libacl-devel libcap-devel libuv-devel libsq3-devel dbus-devel \
                docbook-dtds pam-devel liburing-devel libselinux-devel selinux-policy-devel\
                libattr-devel libsqlite3x-devel libtool libgudev libgudev-devel lz4-devel \
                dnsmasq-utils dnsmasq make rsync squashfs-tools tar xz-devel ruby-devel \
                docbook-utils docbook2X libseccomp-devel libbpf-devel ninja-build

RUN pip install meson && gem install fpm


FROM OEL10builder AS RPM_Builder
ARG LXC_VERSION
ARG INCUS_VERSION
ARG NEBULA_VERSION
ARG NEBULA_ARCH
ARG PREFIX


RUN curl -L -o /var/tmp/lxc-${LXC_VERSION}.tar.gz https://github.com/lxc/lxc/releases/download/v${LXC_VERSION}/lxc-${LXC_VERSION}.tar.gz && \
    curl -L -o /var/tmp/incus-${INCUS_VERSION}.tar.gz https://github.com/lxc/incus/archive/refs/tags/v${INCUS_VERSION}/incus-${INCUS_VERSION}.tar.gz 
      
RUN cd /var/tmp/ && for a in *gz ; do gzip -d < $a | tar -xvf - ; done

RUN cd /var/tmp/lxc-*[0-9]/ && mkdir -p /tmp/lxc-instdir/ &&  meson setup builddir --prefix=/tmp/lxc-instdir/ &&  ninja -C builddir install

RUN cd /tmp/ &&  \
   fpm -s dir -t rpm \
    -n "${PREFIX}-lxc" \
    -v "${LXC_VERSION}" \
    -C /tmp/lxc-instdir \
    $(for n in $(find /tmp/lxc-instdir/bin/ -type f | xargs ldd 2> /dev/null | while read a b c d ; do echo $c ;done | grep / | sort -u)  ; do rpm -q --qf "-d %{NAME} " --whatprovides "$n" ; done) \
    --description "LXC ${LXC_VERSION} built from source" .


RUN dnf install -y /tmp/${PREFIX}-lxc*rpm


RUN cd /var/tmp/incus-*[0-9]/  && make deps && \
       export GOTOOLCHAIN=auto && \
       export CGO_CFLAGS="-I/root/go/deps/raft/include/ -I/root/go/deps/cowsql/include/" && \
       export CGO_LDFLAGS="-L/root/go/deps/raft/.libs -L/root/go/deps/cowsql/.libs/" && \
       export LD_LIBRARY_PATH="/root/go/deps/raft/.libs/:/root/go/deps/cowsql/.libs/" && \
       export CGO_LDFLAGS_ALLOW="(-Wl,-wrap,pthread_create)|(-Wl,-z,now)" && mkdir -p /tmp/incus-instdir/bin  &&  GOBIN=/tmp/incus-instdir/bin make 

RUN cd /tmp/incus-instdir  && mkdir lib && \
      for file in $(ldd bin/* 2> /dev/null | grep not.found |  \
                    grep = | awk '{ print $1}' ) ;  \
        do find /root/go/ -name  ${file%%.[0-9]}\* ;  \
        done | while read line ; do cp -P "$line" lib/ ; done && \
      cd /tmp/ && \
      fpm -s dir -t rpm \
        -n "${PREFIX}-incus" \
        -v "${INCUS_VERSION}" \
        -C /tmp/incus-instdir \
        $(for n in $(find /tmp/incus-instdir/bin/ -type f | xargs ldd 2> /dev/null | while read a b c d ; do echo $c ;done | grep / | sort -u)  ; do rpm -q --qf "-d %{NAME} " --whatprovides "$n" ; done) \
        --description "incus ${INCUS_VERSION} built from source" .


RUN curl -L -o /var/tmp/nebula-linux-v${NEBULA_VERSION}.${NEBULA_ARCH}.tar.gz \
       https://github.com/slackhq/nebula/releases/download/v${NEBULA_VERSION}/nebula-linux-${NEBULA_ARCH}.tar.gz && \
       mkdir -p /tmp/nebula/usr/bin && \
       cd /tmp/nebula/usr/bin && \
       gzip -d < /var/tmp/nebula-linux-v${NEBULA_VERSION}.${NEBULA_ARCH}.tar.gz | tar -xvf - && \
       chown root:root *

RUN cd /tmp/ &&  \
   fpm -s dir -t rpm \
    -n "${PREFIX}-nebula" \
    -v "${NEBULA_VERSION}" \
    -C /tmp/nebula \
    --description "repackaged nebula ${NEBULA_VERSION} from github tarball artifacts" .
