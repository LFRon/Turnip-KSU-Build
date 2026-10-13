#!/usr/bin/env bash
# Phase 00: host dependency check.
# The build hard-requires the tools below; the shader/parser extras are
# recommended and only reported as warnings.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../config.sh"
source "$HERE/lib.sh"

required="meson ninja patchelf unzip zip curl git"
recommended="ccache flex bison glslang glslangValidator pip"

missing=0
for dep in $required; do
    if command -v "$dep" >/dev/null 2>&1; then
        info "found: $dep"
    else
        printf '%b - %s not found, cannot continue.%b\n' "$red" "$dep" "$nocolor"
        missing=1
    fi
done
[ "$missing" = "0" ] || die "please install the missing dependencies"

for dep in $recommended; do
    command -v "$dep" >/dev/null 2>&1 || warn "recommended tool missing: $dep (the build may still work)"
done

if python3 -c 'import mako' >/dev/null 2>&1; then
    info "python mako present"
elif command -v pip >/dev/null 2>&1; then
    log "installing python mako dependency"
    pip install mako >/dev/null 2>&1 || die "failed to install python mako"
elif command -v pip3 >/dev/null 2>&1; then
    log "installing python mako dependency (pip3)"
    pip3 install mako >/dev/null 2>&1 || die "failed to install python mako"
else
    die "python mako is required for the mesa build and pip is unavailable"
fi
