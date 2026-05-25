#!/usr/bin/env bash
# ignore-tidy-linelength

set -eux

hide_output() {
  set +x
  on_err="
echo ERROR: An error was encountered with the build.
cat /tmp/build.log
exit 1
"
  trap "$on_err" ERR
  bash -c "while true; do sleep 30; echo \$(date) - building ...; done" &
  PING_LOOP_PID=$!
  "$@" &> /tmp/build.log
  rm /tmp/build.log
  trap - ERR
  kill $PING_LOOP_PID
  set -x
}

# Download, verify SHA512, and remove the downloaded file
# Usage: <file name> <url> <file sha> <full tar command using fname>
download() {
  fname="$1"
  shift
  url="$1"
  shift
  sha="$1"
  shift

  curl "$url" -o "$fname"
  echo "$sha  $fname" | shasum -a 512 --check || exit 1
  "$@"
  rm "$fname"
}

mkdir netbsd
cd netbsd

mkdir -p /x-tools/m68k-unknown-netbsd/sysroot-x86_64
mkdir -p /x-tools/m68k-unknown-netbsd/sysroot-m68k

# Hashes come from https://nycdn.netbsd.org/pub/NetBSD-daily/netbsd-11/20250924123913Z/source/sets/SHA512 etc.
SRC_SHA=3dc371e98db95f643b884e4d2ac95f7ac3e8b01985d1e4cafc24e4c26ee98ccd8fcd3b75ddac1b25fecb8b27eb7e8781068357a061586253760e2f09ddf9c170
GNUSRC_SHA=8b03851eaa2c0124d6ea61f8dfe2da4502eda18dda109e2185e7a8daff551e52822cc783a6b306a8ecd6ed2765f49178817553604a0a3998f2c745f1c670de97
SHARESRC_SHA=a91720b25056bac3e9b760b393ddd460e22b3834c50363dab94ce258fa8010fddd2889d09868daec6575d8d28fa93afaf309719fa701bf77ee03cf5dc5e8f132
SYSSRC_SHA=04b9217c67b609ad43b48b7249b53c743fab7057373c0e3e1fc8580ba9bb036d2078bccc26fcde87347a4dc5bc5e13e0750b65725f8df54b9bcfbeefaa5df89a
BASE_SHA_X86_64=c8fa82681f82d24639b6f3ad9fee2beb1c76aaee57d25816936205a73a984f69b892372720a93b7fccf8036157b53fcfd2b8f7cc306505eabbfcf468d0e39b0d
COMP_SHA_X86_64=4c75b26a2051036c0bf38fcfff962590a1f4b04132c77520721fa66c83756f9c75c180f0cc9e9e3ff2ae0482e377889c65c9ce75a9026200ed0188625968c403
BASE_SHA_M68K=3512f9ad09cbf06e1734226024f548e11fd83fcc259354de4779e59ee6b10a35c6559dffe670449a94f060d891443eb20df94f91c71978a92075e3621a8f48fc
COMP_SHA_M68K=012c87fb2dbd3dc219d6e3c54253dc21a6757fc8eff9ebb4d1a088fb5fc5e7d88c4683342a44deddbfe9db22ed959540b1dc4ef2790dde26be97b529e95b9f47

SOURCE_URL=https://nycdn.netbsd.org/pub/NetBSD-daily/netbsd-11/20250924123913Z/source/sets
download src.tgz "$SOURCE_URL/src.tgz" "$SRC_SHA" tar xzf src.tgz
download gnusrc.tgz "$SOURCE_URL/gnusrc.tgz" "$GNUSRC_SHA" tar xzf gnusrc.tgz
download sharesrc.tgz "$SOURCE_URL/sharesrc.tgz" "$SHARESRC_SHA" tar xzf sharesrc.tgz
download syssrc.tgz "$SOURCE_URL/syssrc.tgz" "$SYSSRC_SHA" tar xzf syssrc.tgz

X86_64_BINARY_URL=https://nycdn.netbsd.org/pub/NetBSD-daily/netbsd-11/20250924123913Z/amd64/binary/sets
download base.tar.xz "$X86_64_BINARY_URL/base.tar.xz" "$BASE_SHA_X86_64" \
  tar xJf base.tar.xz -C /x-tools/m68k-unknown-netbsd/sysroot-x86_64 ./usr/include ./usr/lib ./lib
download comp.tar.xz "$X86_64_BINARY_URL/comp.tar.xz" "$COMP_SHA_X86_64" \
  tar xJf comp.tar.xz -C /x-tools/m68k-unknown-netbsd/sysroot-x86_64 ./usr/include ./usr/lib


M68K_BINARY_URL=https://nycdn.netbsd.org/pub/NetBSD-daily/netbsd-11/20250924123913Z/virt68k/binary/sets
download base.tar.xz "$M68K_BINARY_URL/base.tgz" "$BASE_SHA_M68K" \
  tar xzf base.tar.xz -C /x-tools/m68k-unknown-netbsd/sysroot-m68k ./usr/include ./usr/lib ./lib
download comp.tar.xz "$M68K_BINARY_URL/comp.tgz" "$COMP_SHA_M68K" \
  tar xzf comp.tar.xz -C /x-tools/m68k-unknown-netbsd/sysroot-m68k ./usr/include ./usr/lib

cd usr/src

# The options, in order, do the following
# * this is an unprivileged build
# * output to a predictable location
# * disable various unneeded stuff
MKUNPRIVED=yes TOOLDIR=/x-tools/m68k-unknown-netbsd \
MKSHARE=no MKDOC=no MKHTML=no MKINFO=no MKKMOD=no MKLINT=no MKMAN=no MKNLS=no MKPROFILE=no \
hide_output ./build.sh -j10 -m amd64 tools

MKUNPRIVED=yes TOOLDIR=/x-tools/m68k-unknown-netbsd \
MKSHARE=no MKDOC=no MKHTML=no MKINFO=no MKKMOD=no MKLINT=no MKMAN=no MKNLS=no MKPROFILE=no \
hide_output ./build.sh -j10 -m mac68k tools

cd ../..

rm -rf usr

cat > /x-tools/m68k-unknown-netbsd/bin/m68k--netbsd-gcc-sysroot <<'EOF'
#!/usr/bin/env bash
exec /x-tools/m68k-unknown-netbsd/bin/m68k--netbsdelf-gcc --sysroot=/x-tools/m68k-unknown-netbsd/sysroot-m68k "$@"
EOF

cat > /x-tools/m68k-unknown-netbsd/bin/m68k--netbsd-g++-sysroot <<'EOF'
#!/usr/bin/env bash
exec /x-tools/m68k-unknown-netbsd/bin/m68k--netbsdelf-g++ --sysroot=/x-tools/m68k-unknown-netbsd/sysroot-m68k "$@"
EOF

GCC_SHA1=`sha1sum -b /x-tools/m68k-unknown-netbsd/bin/m68k--netbsdelf-gcc | cut -d' ' -f1`
GPP_SHA1=`sha1sum -b /x-tools/m68k-unknown-netbsd/bin/m68k--netbsdelf-g++ | cut -d' ' -f1`

echo "# $GCC_SHA1" >> /x-tools/m68k-unknown-netbsd/bin/m68k--netbsd-gcc-sysroot
echo "# $GPP_SHA1" >> /x-tools/m68k-unknown-netbsd/bin/m68k--netbsd-g++-sysroot

chmod +x /x-tools/m68k-unknown-netbsd/bin/m68k--netbsd-gcc-sysroot
chmod +x /x-tools/m68k-unknown-netbsd/bin/m68k--netbsd-g++-sysroot


cat > /x-tools/m68k-unknown-netbsd/bin/x86_64--netbsd-gcc-sysroot <<'EOF'
#!/usr/bin/env bash
exec /x-tools/m68k-unknown-netbsd/bin/x86_64--netbsd-gcc --sysroot=/x-tools/m68k-unknown-netbsd/sysroot-x86_64 "$@"
EOF

cat > /x-tools/m68k-unknown-netbsd/bin/x86_64--netbsd-g++-sysroot <<'EOF'
#!/usr/bin/env bash
exec /x-tools/m68k-unknown-netbsd/bin/x86_64--netbsd-g++ --sysroot=/x-tools/m68k-unknown-netbsd/sysroot-x86_64 "$@"
EOF

GCC_SHA1=`sha1sum -b /x-tools/m68k-unknown-netbsd/bin/x86_64--netbsd-gcc | cut -d' ' -f1`
GPP_SHA1=`sha1sum -b /x-tools/m68k-unknown-netbsd/bin/x86_64--netbsd-g++ | cut -d' ' -f1`

echo "# $GCC_SHA1" >> /x-tools/m68k-unknown-netbsd/bin/x86_64--netbsd-gcc-sysroot
echo "# $GPP_SHA1" >> /x-tools/m68k-unknown-netbsd/bin/x86_64--netbsd-g++-sysroot

chmod +x /x-tools/m68k-unknown-netbsd/bin/x86_64--netbsd-gcc-sysroot
chmod +x /x-tools/m68k-unknown-netbsd/bin/x86_64--netbsd-g++-sysroot
