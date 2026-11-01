#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <folder> <lib folder inside it>" >&2
    exit 1
fi
folder="$(cd "$1" && pwd)"
mkdir -p "$2"
lib="$(cd "$2" && pwd)"

is_macho() {
    [ -f "$1" ] && [ ! -L "$1" ] || return 1
    case "$(head -c 4 "$1" 2>/dev/null || true)" in
        $'\xcf\xfa\xed\xfe' | $'\xca\xfe\xba\xbe') return 0 ;;
    esac
    return 1
}

machos() {
    find "$folder" -type f -print0 | while IFS= read -r -d '' file; do
        if is_macho "$file"; then printf '%s\n' "$file"; fi
    done
}

load_paths() {
    local own
    own="$(otool -D "$1" 2>/dev/null | tail -n +2)"
    otool -L "$1" 2>/dev/null | tail -n +2 | sed -E 's/^[[:space:]]+//; s/ \(compatibility .*//' | while IFS= read -r path; do
        if [ -n "$path" ] && [ "$path" != "$own" ]; then printf '%s\n' "$path"; fi
    done
}

rpaths() {
    otool -l "$1" | awk '/cmd LC_RPATH/ { r = 1; next } r && /path / { print $2; r = 0 }'
}

resolve() {
    local path="$1" file="$2" rpath candidate
    case "$path" in
        /usr/lib/* | /System/*) return ;;
        /*) [ -f "$path" ] && printf '%s\n' "$path"; return ;;
        @rpath/*)
            while IFS= read -r rpath; do
                case "$rpath" in
                    @loader_path*) candidate="$(dirname "$file")${rpath#@loader_path}/${path#@rpath/}" ;;
                    @executable_path*) continue ;;
                    *) candidate="$rpath/${path#@rpath/}" ;;
                esac
                if [ -f "$candidate" ]; then printf '%s\n' "$candidate"; return; fi
            done < <(rpaths "$file")
            ;;
        @loader_path/*)
            candidate="$(dirname "$file")/${path#@loader_path/}"
            [ -f "$candidate" ] && printf '%s\n' "$candidate"
            ;;
    esac
}

pending=()
while IFS= read -r file; do pending+=("$file"); done < <(machos)
index=0
while [ "$index" -lt "${#pending[@]}" ]; do
    file="${pending[$index]}"
    index=$((index + 1))
    while IFS= read -r path; do
        source="$(resolve "$path" "$file")"
        [ -n "$source" ] || continue
        case "$source" in "$folder"/*) continue ;; esac
        target="$lib/$(basename "$path")"
        if [ ! -e "$target" ]; then
            cp -L "$source" "$target"
            chmod u+w "$target"
            pending+=("$target")
        fi
    done < <(load_paths "$file")
done

failed=0
while IFS= read -r file; do
    rpath="@loader_path"
    if [ "$(dirname "$file")" != "$lib" ]; then
        up="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$lib" "$(dirname "$file")")"
        rpath="@loader_path/$up"
    else
        install_name_tool -id "@rpath/$(basename "$file")" "$file" 2>/dev/null
    fi
    while IFS= read -r path; do
        name="$(basename "$path")"
        case "$path" in /usr/lib/* | /System/*) continue ;; esac
        if [ -e "$lib/$name" ]; then
            [ "$path" = "@rpath/$name" ] || install_name_tool -change "$path" "@rpath/$name" "$file" 2>/dev/null
        elif [[ "$path" == /* ]]; then
            echo "Unbundled dependency in $file: $path" >&2
            failed=1
        fi
    done < <(load_paths "$file")
    while IFS= read -r old; do
        case "$old" in /*) install_name_tool -delete_rpath "$old" "$file" 2>/dev/null || true ;; esac
    done < <(rpaths "$file")
    rpaths "$file" | grep -F -q -x -- "$rpath" || install_name_tool -add_rpath "$rpath" "$file" 2>/dev/null
    codesign --force --sign - "$file" 2>/dev/null
done < <(machos)
exit "$failed"
