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

# The boot scripts serve the HAL themselves only when the install-time
# attribute says KernelSU; report it together with the metamodule, if any.
attr=$(grep -m1 '^KernelSU_Module=' "$MODDIR/module.prop" 2>/dev/null)
echo "criterion: ${attr:-KernelSU_Module=<unset>}"
if [ -d /data/adb/metamodule ]; then
    echo "metamodule: $(readlink /data/adb/metamodule 2>/dev/null)"
fi

# Compare the live HAL with the payload, count the module's own binds at the
# path and report how the file is supplied.
for arch in lib64 lib; do
    dst="/vendor/$arch/hw/$HAL"
    src="$MODDIR/system/vendor/$arch/hw/$HAL"
    [ -f "$src" ] || src="$MODDIR/vendor/$arch/hw/$HAL"
    [ -e "$dst" ] || continue
    [ -f "$src" ] || continue
    if cmp -s "$dst" "$src" 2>/dev/null; then
        state="active (serving the payload)"
    else
        state="STOCK (payload not applied)"
    fi
    own=$(grep -cs " $src " /proc/self/mountinfo 2>/dev/null)
    mnt=$(grep " $dst " /proc/mounts 2>/dev/null | awk 'NR==1{print $3}')
    if [ -n "$mnt" ]; then
        echo "$arch: $state; mount=$mnt; module binds=$own"
    else
        echo "$arch: $state; no mount (injected); module binds=$own"
    fi
done

if [ -f "$MODDIR/provision.log" ]; then
    echo "--- provision.log (tail) ---"
    tail -n 6 "$MODDIR/provision.log" 2>/dev/null
fi

echo "Disable this module and reboot to restore the stock Adreno Vulkan driver."
