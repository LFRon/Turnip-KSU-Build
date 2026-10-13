# Match Android's vendor HAL path labels exactly.  In particular, hw must be
# vendor_hal_file: labelling that directory vendor_file prevents framework
# processes such as SurfaceFlinger from enumerating the gralloc mapper HALs.
#
# The HAL is shipped under both the Magisk system/ overlay and the top-level
# vendor/ overlay (64-bit and 32-bit).  Every directory the driver lives in
# must carry the vendor_hal_file label and the file itself the
# same_process_hal_file label, regardless of which overlay the manager mounts.
set_perm_recursive $MODPATH/system 0 0 0755 0644 u:object_r:system_file:s0
set_perm $MODPATH/system/vendor 0 0 0755 u:object_r:vendor_file:s0
set_perm $MODPATH/system/vendor/lib64 0 0 0755 u:object_r:vendor_file:s0
set_perm $MODPATH/system/vendor/lib64/hw 0 0 0755 u:object_r:vendor_hal_file:s0
set_perm $MODPATH/system/vendor/lib64/hw/vulkan.adreno.so 0 0 0644 u:object_r:same_process_hal_file:s0
set_perm $MODPATH/system/vendor/lib 0 0 0755 u:object_r:vendor_file:s0
set_perm $MODPATH/system/vendor/lib/hw 0 0 0755 u:object_r:vendor_hal_file:s0
set_perm $MODPATH/system/vendor/lib/hw/vulkan.adreno.so 0 0 0644 u:object_r:same_process_hal_file:s0
set_perm $MODPATH/vendor 0 0 0755 u:object_r:vendor_file:s0
set_perm $MODPATH/vendor/lib64 0 0 0755 u:object_r:vendor_file:s0
set_perm $MODPATH/vendor/lib64/hw 0 0 0755 u:object_r:vendor_hal_file:s0
set_perm $MODPATH/vendor/lib64/hw/vulkan.adreno.so 0 0 0644 u:object_r:same_process_hal_file:s0
set_perm $MODPATH/vendor/lib 0 0 0755 u:object_r:vendor_file:s0
set_perm $MODPATH/vendor/lib/hw 0 0 0755 u:object_r:vendor_hal_file:s0
set_perm $MODPATH/vendor/lib/hw/vulkan.adreno.so 0 0 0644 u:object_r:same_process_hal_file:s0

# KernelSU metamodules honour the standard skip_mount flag (KernelSU
# metamodule contract) and must not stage this module: the HAL is supplied by
# post-fs-data.sh alone.  The standard KernelSU installer only processes the
# SKIPMOUNT variable on the legacy path, so the marker is created directly.
# Magisk mounts natively instead, so a stale marker is removed there.
if [ "$KSU" = "true" ]; then
	: > "$MODPATH/skip_mount"
else
	rm -f "$MODPATH/skip_mount"
fi
