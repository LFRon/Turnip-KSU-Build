#!/usr/bin/env bash
# Phase 00: host dependency check (mirrors the original builder list + git).

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../config.sh"
source "$HERE/lib.sh"

deps="meson ninja patchelf unzip curl pip flex bison zip glslang glslangValidator git"

missing=0
for dep in $deps; do
    if command -v "$dep" >/dev/null 2>&1; then
        info "found: $dep"
    else
        printf '%b - %s not found, cannot continue.%b\n' "$red" "$dep" "$nocolor"
        missing=1
    fi
done
[ "$missing" = "0" ] || die "please install the missing dependencies"

if python3 -c 'import mako' >/dev/null 2>&1; then
    info "python mako present"
else
    log "installing python mako dependency"
    pip install mako >/dev/null 2>&1 || pip3 install mako >/dev/null 2>&1 \
        || die "failed to install python mako"
fi
