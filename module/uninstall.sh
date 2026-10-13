#!/system/bin/sh
# Undo the KernelSU self-mounts set up by post-fs-data.sh.  Mounts also
# vanish on reboot; this keeps module removal clean.
HAL="vulkan.adreno.so"
for dst in "/vendor/lib64/hw/$HAL" "/vendor/lib/hw/$HAL"; do
	[ -e "$dst" ] && umount "$dst" 2>/dev/null
done
rm -f "/dev/.vendor_hal/$HAL" 2>/dev/null
rmdir "/dev/.vendor_hal" 2>/dev/null
exit 0
