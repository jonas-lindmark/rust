FROM debian:trixie

ARG DEBIAN_FRONTEND=noninteractive
COPY scripts/cross-apt-packages.sh /scripts/
RUN sh /scripts/cross-apt-packages.sh
RUN apt-get install -y zlib1g-dev

COPY host-x86_64/dist-m68k-netbsd/build-netbsd-toolchain.sh /tmp/
RUN /tmp/build-netbsd-toolchain.sh

COPY scripts/sccache.sh /scripts/
RUN sh /scripts/sccache.sh

ENV PATH=$PATH:/x-tools/m68k-unknown-netbsd/bin

ENV \
    AR_m68k_unknown_netbsd=m68k--netbsdelf-ar \
    CC_m68k_unknown_netbsd=m68k--netbsd-gcc-sysroot \
    CXX_m68k_unknown_netbsd=m68k--netbsd-g++-sysroot \
    AR_x86_64_unknown_netbsd=x86_64--netbsd-ar \
    CC_x86_64_unknown_netbsd=x86_64--netbsd-gcc-sysroot \
    CXX_x86_64_unknown_netbsd=x86_64--netbsd-g++-sysroot

ENV HOST=x86_64-unknown-netbsd
ENV TARGET=m68k-unknown-netbsd


ENV RUST_CONFIGURE_ARGS --enable-extended --disable-docs
ENV SCRIPT python3 ../x.py dist --host $HOST --target $TARGET
