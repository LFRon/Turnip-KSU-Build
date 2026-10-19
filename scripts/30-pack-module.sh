#!/usr/bin/env bash
# Phase 30: pack the Magisk/KernelSU module.
#
# The payload under module/ is the zip root and is shipped verbatim; the HAL
# is copied into every device path listed in config.sh after the soname has
# been patched to vulkan.adreno.so.  Versions live in module/module.prop and
# are never rewritten here.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../config.sh"
source "$HERE/lib.sh"

hal_src="${HAL:-$hal_artifact}"
[ -f "$hal_src" ] || die "HAL not found: $hal_src (build mesa first or pass --hal)"
[ "$(LC_ALL=C head -c 4 "$hal_src")" = "$(printf '\177ELF')" ] || die "not an ELF shared object: $hal_src"
need_cmd patchelf
need_cmd zip
need_cmd unzip

stage="$WORKDIR/pack-module"
rm -rf "$stage"
mkdir -p "$stage"
cp -a "$MODULE_DIR/." "$stage/"

grep -q "^id=$module_id$" "$stage/module.prop" || die "module.prop: id must be $module_id"
grep -q '^version=' "$stage/module.prop" || die "module.prop: version is missing"
grep -q '^versionCode=' "$stage/module.prop" || die "module.prop: versionCode is missing"

# Regression guard: KernelSU >= 3 mounts no module files by itself, so the
# payload must keep the scripts that serve the HAL itself, must carry the
# dedicated KernelSU_Module attribute, and must never create skip_mount.
# Losing any of this silently breaks the KernelSU supply model.
for f in customize.sh action.sh post-fs-data.sh post-mount.sh uninstall.sh turnip-provision.sh system.prop; do
    [ -f "$stage/$f" ] || die "module payload lost required file: $f"
done
grep -q '^KernelSU_Module=' "$stage/module.prop" || die "module.prop: KernelSU_Module attribute is missing"
grep -q 'KernelSU_Module=' "$stage/customize.sh" || die "customize.sh no longer stamps the attribute"
grep -q 'KernelSU_Module=true' "$stage/post-fs-data.sh" || die "post-fs-data.sh lost the attribute criterion"
grep -q 'KernelSU_Module=true' "$stage/post-mount.sh" || die "post-mount.sh lost the attribute criterion"
grep -q 'turnip-provision.sh' "$stage/post-fs-data.sh" || die "post-fs-data.sh no longer provisions"
grep -q 'turnip-provision.sh' "$stage/post-mount.sh" || die "post-mount.sh no longer provisions"
grep -q 'rm -f "\$MODPATH/skip_mount"' "$stage/customize.sh" || die "customize.sh no longer clears skip_mount"
if grep -qE '(: *> *"\$MODPATH/skip_mount"|touch .*skip_mount)' "$stage/customize.sh"; then
    die "customize.sh must not create skip_mount"
fi

log "patching soname to $hal_name"
hal_tmp="$stage/.hal.soname.tmp"
cp "$hal_src" "$hal_tmp"
patchelf --set-soname "$hal_name" "$hal_tmp"
[ "$(patchelf --print-soname "$hal_tmp")" = "$hal_name" ] || die "soname patch failed"

for path in "${hal_paths[@]}"; do
    mkdir -p "$stage/$path"
    cp "$hal_tmp" "$stage/$path/$hal_name"
    count="$(find "$stage/$path" -maxdepth 1 -type f -name 'vulkan.*.so' | wc -l)"
    [ "$count" -eq 1 ] || die "expected exactly one Vulkan HAL in $path (found $count)"
done
rm -f "$hal_tmp"

mkdir -p "$OUTDIR"
rm -f "$OUTDIR/turnip.zip"
( cd "$stage" && zip -r "$OUTDIR/turnip.zip" ./* >/dev/null )
unzip -tq "$OUTDIR/turnip.zip" >/dev/null || die "zip integrity check failed"
files="$(find "$stage" -type f | wc -l)"
info "packed $OUTDIR/turnip.zip ($(stat -c %s "$OUTDIR/turnip.zip") bytes, $files files)"
