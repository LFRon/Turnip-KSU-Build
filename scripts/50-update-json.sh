#!/usr/bin/env bash
# Phase 50: generate out/update.json for the module update channel.
# Version data comes from module/module.prop (the single maintained file);
# the download base comes from RELEASE_BASE in config.sh.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../config.sh"
source "$HERE/lib.sh"

version="$(sed -n 's/^version=//p' "$MODULE_DIR/module.prop" | head -n 1)"
version_code="$(sed -n 's/^versionCode=//p' "$MODULE_DIR/module.prop" | head -n 1)"
[ -n "$version" ] || die "module.prop: version is missing"
[ -n "$version_code" ] || die "module.prop: versionCode is missing"

mkdir -p "$OUTDIR"
cat > "$OUTDIR/update.json" <<EOF
{
  "version": "$version",
  "versionCode": $version_code,
  "zipUrl": "$RELEASE_BASE/turnip.zip",
  "changelog": "$RELEASE_BASE/changelog.md"
}
EOF

if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$OUTDIR/update.json" >/dev/null || die "generated update.json is invalid"
fi
info "wrote $OUTDIR/update.json (version=$version, versionCode=$version_code)"
