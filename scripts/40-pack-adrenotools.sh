#!/usr/bin/env bash
# Phase 40: pack the adrenotools variant (soname vulkan.freedreno.so plus
# meta.json), keeping parity with the original builder.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../config.sh"
source "$HERE/lib.sh"

hal_src="${HAL:-$hal_artifact}"
[ -f "$hal_src" ] || die "HAL not found: $hal_src (build mesa first or pass --hal)"
need_cmd patchelf
need_cmd zip
need_cmd unzip

stage="$WORKDIR/pack-adrenotools"
rm -rf "$stage"
mkdir -p "$stage"

log "patching soname to $adrenotools_name"
cp "$hal_src" "$stage/$adrenotools_name"
patchelf --set-soname "$adrenotools_name" "$stage/$adrenotools_name"
[ "$(patchelf --print-soname "$stage/$adrenotools_name")" = "$adrenotools_name" ] \
    || die "soname patch failed"

log "writing meta.json"
cat > "$stage/meta.json" <<EOF
{
	"schemaVersion": 1,
	"name": "Turnip-KSU-Build",
	"description": "$(date)",
	"author": "MrMiy4mo, kethen",
	"packageVersion": "1",
	"vendor": "Mesa",
	"driverVersion": "$(cat "$MESA_DIR/VERSION" 2>/dev/null || echo unknown)",
	"minApi": $sdkver,
	"libraryName": "$adrenotools_name"
}
EOF

mkdir -p "$OUTDIR"
rm -f "$OUTDIR/turnip_adrenotools.zip"
( cd "$stage" && zip -9 "$OUTDIR/turnip_adrenotools.zip" "$adrenotools_name" meta.json >/dev/null )
unzip -tq "$OUTDIR/turnip_adrenotools.zip" >/dev/null || die "zip integrity check failed"
info "packed $OUTDIR/turnip_adrenotools.zip ($(stat -c %s "$OUTDIR/turnip_adrenotools.zip") bytes)"
