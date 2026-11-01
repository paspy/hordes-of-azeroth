#!/bin/bash
set -euo pipefail

version="${1:-11.4.13}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$root/release/build/macos/mariadb"
source_tarball="$root/server/downloads/mariadb-$version.tar.gz"
source="$work/mariadb-$version"
build="$work/build"
stage="$work/mariadb-$version-macos-arm64"
out="$root/release/build/macos/mariadb-$version-macos-arm64.tar.gz"

mkdir -p "$work" "$(dirname "$source_tarball")"
if [ ! -f "$source_tarball" ]; then
    curl -fL --retry 3 -o "$source_tarball.part" "https://archive.mariadb.org/mariadb-$version/source/mariadb-$version.tar.gz"
    mv "$source_tarball.part" "$source_tarball"
fi
if [ ! -d "$source" ]; then
    tar -xzf "$source_tarball" -C "$work"
fi

cmake -S "$source" -B "$build" -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX="$stage" \
    -DINSTALL_LAYOUT=STANDALONE \
    -DBISON_EXECUTABLE="$(brew --prefix bison)/bin/bison" \
    -DWITH_SSL=bundled -DWITH_PCRE=bundled -DWITH_ZLIB=bundled \
    -DWITH_UNIT_TESTS=OFF -DWITH_EMBEDDED_SERVER=OFF -DWITH_WSREP=OFF -DWITH_MARIABACKUP=OFF \
    -DCONC_WITH_UNIT_TESTS=OFF -DWITH_LIBFMT=bundled \
    -DPLUGIN_ROCKSDB=NO -DPLUGIN_MROONGA=NO -DPLUGIN_SPIDER=NO -DPLUGIN_CONNECT=NO \
    -DPLUGIN_S3=NO -DPLUGIN_COLUMNSTORE=NO -DPLUGIN_OQGRAPH=NO -DPLUGIN_SPHINX=NO \
    -DPLUGIN_AUTH_GSSAPI=NO -DPLUGIN_AUTH_GSSAPI_CLIENT=OFF -DPLUGIN_HASHICORP_KEY_MANAGEMENT=NO \
    -DPLUGIN_PROVIDER_LZ4=NO -DPLUGIN_PROVIDER_LZO=NO -DPLUGIN_PROVIDER_LZMA=NO \
    -DPLUGIN_PROVIDER_SNAPPY=NO -DPLUGIN_PROVIDER_BZIP2=NO -DPLUGIN_PROVIDER_ZSTD=NO
cmake --build "$build"
rm -rf "$stage"
cmake --install "$build"
rm -rf "$stage/mariadb-test" "$stage/sql-bench" "$stage/man" "$stage/docs" "$stage/include" "$stage/lib/pkgconfig"
rm -f "$stage"/lib/*.a

"$root/tools/macos/bundle-dylibs.sh" "$stage" "$stage/lib"

rm -f "$out"
tar -czf "$out" -C "$(dirname "$stage")" "$(basename "$stage")"
echo "MariaDB package: $out"
