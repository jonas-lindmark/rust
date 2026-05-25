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
SRC_SHA=c238f6180ae7c89106cbb20560fe9c058d0f646b50ef17f72fc01cdb3bf0f28974b526f977971b430de911f7e5867f07859534541c61452aba1b726af2483ae5
GNUSRC_SHA=41bf4ba82eac752ca689e0fdc23e419af776c59af259823d9d13c03079a9703a182cc172d08b1c46249cf5193d2afbdfc405b5a6dfa573d7bf9aba59c2529799
SHARESRC_SHA=aaab14cd74824cc9b6c96c10131e9c6117858fe12b7b594570340528611b1a2f8457a71e86c2375fbe4d9413cdf706a920a4789efd9cee1b75a360f31a21be12
SYSSRC_SHA=7ad9917c3936c8d72b185364b91b3beb00a945001e3a416436880ea14682ff00958590966c0e79e86ca36b9918670da77cef1e5c7f38945388a581925c04bd30
BASE_SHA_X86_64=a991d532cc208348870ba40b7742009d142668e3f073cb4cf9feac3bb90dc6b145c897ff73ecbff686986fbc0b66837aa4780a33d67e979aba5ebcca10b5a7d4
COMP_SHA_X86_64=eb863ab9abfcb780b27aac0f7866d50c957be97797c6c8dd41252c59602b75834f700e64aa4e46d215fdfd978a9c3892092135029cbe112e7c20c4f69d08b1e1
BASE_SHA_M68K=bc9076e204ced918fb6dc9408e284c5d890a8c8a36981528950003a3143ea62881d331324fdb4529b65a4b1e646564424f5d905da3f328af2c6c6cfd9e8b92dc
COMP_SHA_M68K=b17c4b752a696db9557d9667b8bfca14cfe1b3e40aaa313dff2d680a0571cf0394b18fbea0870a00ebdff8289a6d6a633c06c1efadc8d948990e79038bcd5b51

SOURCE_URL=https://cdn.netbsd.org/pub/NetBSD/NetBSD-11.0_RC4/source/sets/
download src.tgz "$SOURCE_URL/src.tgz" "$SRC_SHA" tar xzf src.tgz
download gnusrc.tgz "$SOURCE_URL/gnusrc.tgz" "$GNUSRC_SHA" tar xzf gnusrc.tgz
download sharesrc.tgz "$SOURCE_URL/sharesrc.tgz" "$SHARESRC_SHA" tar xzf sharesrc.tgz
download syssrc.tgz "$SOURCE_URL/syssrc.tgz" "$SYSSRC_SHA" tar xzf syssrc.tgz

X86_64_BINARY_URL=https://cdn.netbsd.org/pub/NetBSD/NetBSD-11.0_RC4/amd64/binary/sets/
download base.tar.xz "$X86_64_BINARY_URL/base.tar.xz" "$BASE_SHA_X86_64" \
  tar xJf base.tar.xz -C /x-tools/m68k-unknown-netbsd/sysroot-x86_64 ./usr/include ./usr/lib ./lib
download comp.tar.xz "$X86_64_BINARY_URL/comp.tar.xz" "$COMP_SHA_X86_64" \
  tar xJf comp.tar.xz -C /x-tools/m68k-unknown-netbsd/sysroot-x86_64 ./usr/include ./usr/lib

M68K_BINARY_URL=https://cdn.netbsd.org/pub/NetBSD/NetBSD-11.0_RC4/virt68k/binary/sets/
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
