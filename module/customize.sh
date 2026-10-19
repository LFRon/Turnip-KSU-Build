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

# Stamp the dedicated attribute that the boot scripts use as their single
# criterion for serving the HAL themselves (post-fs-data.sh / post-mount.sh):
# only a KernelSU install gets `true`, so Magisk and every other manager keep
# mounting the canonical payload natively and never enter that path.
if [ "$KSU" = "true" ]; then
    _turnip_attr=true
else
    _turnip_attr=false
fi
if grep -q '^KernelSU_Module=' "$MODPATH/module.prop" 2>/dev/null; then
    sed -i "s/^KernelSU_Module=.*/KernelSU_Module=$_turnip_attr/" "$MODPATH/module.prop"
else
    echo "KernelSU_Module=$_turnip_attr" >>"$MODPATH/module.prop"
fi

# skip_mount is never used: every manager keeps seeing the canonical payload.
# Remove a stale marker left over from the removed v3 self-mount package.
rm -f "$MODPATH/skip_mount"
