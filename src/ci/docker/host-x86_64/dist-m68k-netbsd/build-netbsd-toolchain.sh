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
SRC_SHA=4934fee580f48485f8fa78601af6bc4d07498ae6d2877acb6de4add3f1bd3f0e0cf075b076dd411c23416ad20a9c2ae91ec96e87a06f9572d72f872f8b8ea958
GNUSRC_SHA=19cc8a45ff3f64e75a1d1fd059cbb9b654ffed287fbcc5dc89a9e9ab67e6ac18a4670d9f0c5a389e3bdacab1dd4c2f11c47ec3b8eef7cb511e5994366f6d59a1
SHARESRC_SHA=ae1c2e557821679dc4179b6b5d4e1379dcc30b040116693a58f403c9d9b8c30704220262deab1f9db680538d7bded66c3a4f2b6889025827f6212fb1cf59fdd5
SYSSRC_SHA=405a7743badf2382d329376a50a15ef5e22ecea18c649cfff7efacd274b6f93c8756953c993dfbcba94fafa6ff21ba191b6c35dad71df8e22122a9a1d3d3ebd1
BASE_SHA_X86_64=711f08ce985d6eada683eb9e410b18116257d765193fa93d5c2c63e040398a554db26598e6ff861337312a15891c59034077e817f84d10347130c61fb36c6387
COMP_SHA_X86_64=defc2599863430c18435097c020f550c1920e9c62d3ab82c07815cffa38411785fb6a2a5bfa604e091afe377dd67c9ae09770fb1337d74cc76efff2b29f474c3
BASE_SHA_M68K=55f55b1f14e59215f25cc15a7546ee20d226eeefd3310af205736d7ca3bf59956c2cf2891708c7c29b83f376c658c88c2f8cc13def01c762a271aace9525a519
COMP_SHA_M68K=5a894a9f06030577ff7ed3e6fcf573177cd23848713669101a82a3af5597c1044834d7844e46e84a4d3dc8f7ebd54e10e3bbcae0e4100536b187c132e1799c9a

SOURCE_URL=https://cdn.netbsd.org/pub/NetBSD/NetBSD-9.4/source/sets/
download src.tgz "$SOURCE_URL/src.tgz" "$SRC_SHA" tar xzf src.tgz
download gnusrc.tgz "$SOURCE_URL/gnusrc.tgz" "$GNUSRC_SHA" tar xzf gnusrc.tgz
download sharesrc.tgz "$SOURCE_URL/sharesrc.tgz" "$SHARESRC_SHA" tar xzf sharesrc.tgz
download syssrc.tgz "$SOURCE_URL/syssrc.tgz" "$SYSSRC_SHA" tar xzf syssrc.tgz

X86_64_BINARY_URL=https://cdn.netbsd.org/pub/NetBSD/NetBSD-9.4/amd64/binary/sets/
download base.tar.xz "$X86_64_BINARY_URL/base.tar.xz" "$BASE_SHA_X86_64" \
  tar xJf base.tar.xz -C /x-tools/m68k-unknown-netbsd/sysroot-x86_64 ./usr/include ./usr/lib ./lib
download comp.tar.xz "$X86_64_BINARY_URL/comp.tar.xz" "$COMP_SHA_X86_64" \
  tar xJf comp.tar.xz -C /x-tools/m68k-unknown-netbsd/sysroot-x86_64 ./usr/include ./usr/lib

M68K_BINARY_URL=https://cdn.netbsd.org/pub/NetBSD/NetBSD-9.4/mac68k/binary/sets/
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
