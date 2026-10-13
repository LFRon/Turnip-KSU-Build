# Match Android's vendor HAL path labels exactly.  In particular, hw must be
# vendor_hal_file: labelling that directory vendor_file prevents framework
# processes such as SurfaceFlinger from enumerating the gralloc mapper HALs.
#
# The HAL ships as the module's canonical system/ payload; the installed
# manager (a KernelSU metamodule, or Magisk) is the component that mounts or
# injects it, and these labels travel with the files into the visible tree.
set_perm_recursive $MODPATH/system 0 0 0755 0644 u:object_r:system_file:s0
set_perm $MODPATH/system/vendor 0 0 0755 u:object_r:vendor_file:s0
set_perm $MODPATH/system/vendor/lib64 0 0 0755 u:object_r:vendor_file:s0
set_perm $MODPATH/system/vendor/lib64/hw 0 0 0755 u:object_r:vendor_hal_file:s0
set_perm $MODPATH/system/vendor/lib64/hw/vulkan.adreno.so 0 0 0644 u:object_r:same_process_hal_file:s0
set_perm $MODPATH/system/vendor/lib 0 0 0755 u:object_r:vendor_file:s0
set_perm $MODPATH/system/vendor/lib/hw 0 0 0755 u:object_r:vendor_hal_file:s0
set_perm $MODPATH/system/vendor/lib/hw/vulkan.adreno.so 0 0 0644 u:object_r:same_process_hal_file:s0

# The earlier self-mount package set the standard skip_mount marker to keep
# metamodules away from this module.  That design is gone: every manager is
# now expected to provide the payload through its standard path, and a stale
# marker would silently make all of them skip it.  A KernelSU update replaces
# the module directory anyway; this covers manual extraction and other
# managers.
rm -f "$MODPATH/skip_mount"
