#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
build="$root/server/build"
stage="$root/server/build/install"
run="$root/server/run"
mysql_client="$(brew --prefix mysql-client@8.4)"
openssl="$(brew --prefix openssl@3)"

cmake -S "$root/server/core" -B "$build" -DCMAKE_BUILD_TYPE=Release \
    "-DCMAKE_PREFIX_PATH=$openssl;$mysql_client" \
    -DBUILD_EXTRACTORS=1 -DBUILD_FOR_HOST_CPU=OFF -DCONF_DIR:STRING=. \
    "-DCMAKE_INSTALL_PREFIX=$stage"
cmake --build "$build" -j"$(sysctl -n hw.ncpu)"
rm -rf "$stage"
cmake --install "$build"

mkdir -p "$run/Extractors"
cp -f "$stage/bin/mangosd" "$stage/bin/realmd" "$run/"
cp -f "$stage"/bin/Extractors/* "$run/Extractors/"
cp -f "$stage"/*.conf.dist "$run/"
echo "Server installed into $run"
