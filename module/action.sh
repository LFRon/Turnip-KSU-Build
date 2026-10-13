#!/system/bin/sh
MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=$(pwd)
HAL="vulkan.adreno.so"

if [ "$(getprop ro.hardware.vulkan)" = "adreno" ]; then
    echo "ro.hardware.vulkan=adreno (Turnip naming active)"
else
    resetprop ro.hardware.vulkan adreno
    echo "ro.hardware.vulkan corrected to adreno; reboot required."
fi

if [ "$KSU" = "true" ] && [ -e /data/adb/metamodule ]; then
    echo "metamodule: $(readlink /data/adb/metamodule 2>/dev/null)"
fi

# Compare the live HAL with the payload and report how it is supplied:
# a mount entry means a mount-based manager (overlay/magic mount), no entry
# with matching content means a no-mount injection (e.g. VFS redirection).
for arch in lib64 lib; do
    dst="/vendor/$arch/hw/$HAL"
    src="$MODDIR/system/vendor/$arch/hw/$HAL"
    [ -e "$dst" ] || continue
    [ -f "$src" ] || continue
    if cmp -s "$dst" "$src" 2>/dev/null; then
        state="active (serving the payload)"
    else
        state="STOCK (payload not applied)"
    fi
    mnt=$(grep " $dst " /proc/mounts 2>/dev/null | awk 'NR==1{print $3}')
    if [ -n "$mnt" ]; then
        echo "$arch: $state; mount=$mnt"
    else
        echo "$arch: $state; no mount (injected)"
    fi
done

echo "Disable this module and reboot to restore the stock Adreno Vulkan driver."
