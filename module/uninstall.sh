#!/system/bin/sh
# Detach this module's own binds (post-fs-data and post-mount may have stacked
# two) so the stock HAL is served again right away; a reboot clears them as
# well.  Only mounts whose source is this module's payload are touched, so a
# metamodule's mounts stay untouched.

MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=$(pwd)
HAL=vulkan.adreno.so

for arch in lib64 lib; do
    dst="/vendor/$arch/hw/$HAL"
    src="$MODDIR/system/vendor/$arch/hw/$HAL"
    [ -f "$src" ] || src="$MODDIR/vendor/$arch/hw/$HAL"
    [ -f "$src" ] || continue
    n=0
    while [ "$n" -lt 3 ] && grep -qs " $src " /proc/self/mountinfo; do
        umount "$dst" 2>/dev/null || break
        n=$((n + 1))
    done
done

exit 0
