FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
COPY scripts/cross-apt-packages.sh /scripts/
RUN sh /scripts/cross-apt-packages.sh
RUN apt-get install -y zlib1g-dev

COPY host-x86_64/dist-m68k-netbsd/build-netbsd-toolchain.sh /tmp/
# GCC 10 changed the default to -fno-common, which causes errors with the NetBSD-9.0 sources like:
# /usr/bin/ld: buf.o:(.bss+0x0): multiple definition of `debug_file'; arch.o:(.bss+0x0): first defined here
RUN env HOST_CFLAGS="-O -fcommon" /tmp/build-netbsd-toolchain.sh

COPY scripts/sccache.sh /scripts/
RUN sh /scripts/sccache.sh

ENV PATH=$PATH:/x-tools/m68k-unknown-netbsd/bin

ENV \
    AR_m68k_unknown_netbsd=m68k--netbsdelf-ar \
    CC_m68k_unknown_netbsd=m68k--netbsd-gcc-sysroot \
    CXX_m68k_unknown_netbsd=m68k--netbsd-g++-sysroot

ENV HOSTS=m68k-unknown-netbsd


ENV RUST_CONFIGURE_ARGS --enable-extended --disable-docs
ENV SCRIPT python3 ../x.py dist --host $HOSTS --target $HOSTS
