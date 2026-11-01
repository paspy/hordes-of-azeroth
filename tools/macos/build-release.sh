#!/bin/bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 server|client <source> <out>" >&2
    exit 1
fi
part="$1"
source="$(cd "$2" && pwd)"
mkdir -p "$3"
out="$(cd "$3" && pwd)"
here="$(cd "$(dirname "$0")" && pwd)"
deployment_target=26.0

build_server() {
    local build="$out/server-build" install="$out/server-install" package="$out/server"
    cmake -S "$source" -B "$build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
        "-DCMAKE_PREFIX_PATH=$(brew --prefix openssl@3);$(brew --prefix mysql-client@8.4)" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=$deployment_target \
        -DBUILD_EXTRACTORS=1 -DBUILD_FOR_HOST_CPU=OFF -DCONF_DIR:STRING=. \
        "-DCMAKE_INSTALL_PREFIX=$install"
    cmake --build "$build"
    rm -rf "$install" "$package"
    cmake --install "$build"
    mkdir -p "$package/Extractors"
    cp "$install/bin/mangosd" "$install/bin/realmd" "$install"/*.conf.dist "$package/"
    cp "$install"/bin/Extractors/* "$package/Extractors/"
    strip -x "$package/mangosd" "$package/realmd" "$package"/Extractors/*Extractor "$package/Extractors/VMapAssembler" "$package/Extractors/MoveMapGenerator"
    "$here/bundle-dylibs.sh" "$package" "$package/lib"
}

build_client() {
    local target="$out/client-target" package="$out/client"
    MACOSX_DEPLOYMENT_TARGET=$deployment_target CARGO_TARGET_DIR="$target" \
        cargo build --manifest-path "$source/Cargo.toml" --profile ship --locked -p hoa --no-default-features
    rm -rf "$package"
    mkdir -p "$package"
    cp "$target/ship/HordesOfAzeroth" "$package/HordesOfAzeroth"
    "$here/bundle-dylibs.sh" "$package" "$package/lib"
    rmdir "$package/lib" 2>/dev/null || true
}

case "$part" in
    server) build_server ;;
    client) build_client ;;
    *) echo "Unknown part $part" >&2; exit 1 ;;
esac
