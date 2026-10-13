#!/system/bin/sh
MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=$(pwd)

if [ "$(getprop ro.hardware.vulkan)" = "adreno" ]; then
    echo "Turnip is already active as vulkan.adreno.so."
else
    resetprop ro.hardware.vulkan adreno
    echo "Vulkan HAL name corrected to adreno; reboot required."
fi
if [ "$KSU" = "true" ]; then
    for dst in "/vendor/lib64/hw/vulkan.adreno.so" "/vendor/lib/hw/vulkan.adreno.so"; do
        fstype=$(grep " $dst " /proc/mounts 2>/dev/null | awk 'NR==1{print $3}')
        if [ -n "$fstype" ]; then
            echo "KernelSU self-mount: active ($fstype) [$dst]"
        else
            echo "KernelSU self-mount: missing [$dst]"
        fi
    done
    if [ -e "$MODDIR/skip_mount" ]; then
        echo "skip_mount: present (metamodules skip this module)"
    else
        echo "skip_mount: MISSING (metamodules may stage this module)"
    fi
fi
echo "Disable this module and reboot to restore the stock Adreno Vulkan driver."
