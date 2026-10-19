#!/system/bin/sh
# Turnip self-provisioning on KernelSU.
#
# The single criterion for taking the KernelSU path is the dedicated
# module.prop attribute `KernelSU_Module=true`; customize.sh stamps it at
# install time (only a KernelSU install gets `true`), so Magisk and every
# other manager keep mounting the canonical payload natively and never see
# any of this logic.
#
# Why the module also serves the HAL itself on KernelSU:
#   * KernelSU >= 3 mounts no module files by itself; a metamodule's
#     metamount.sh is the only mount stage (latest release v3.3.1:
#     init_event.rs on_post_fs_data -> metamodule::exec_mount_script), so
#     without a metamodule nothing is supplied at all.
#   * KernelSU's per-app "unmount modules" feature only detaches mounts whose
#     source is the KSU marker: metamodule.md requires metamodules to set
#     source/device "KSU" so KernelSU can identify and manage them, and
#     kernel/feature/kernel_umount.c only walks that umount list.  A plain
#     bind like ours carries no KSU marker, so it survives per-app unmounting
#     and keeps Turnip available even when "unmount modules by default" is
#     enabled -- the reason this module never relies on a metamodule alone.
#
# Placement matters: this stage runs *before* the metamodule's metamount.sh
# (fixed KernelSU order: metamodule post-fs-data -> module scripts ->
# system.prop -> metamount.sh -> post-mount scripts), so the bind ends up
# below any metamodule mount -- per-app unmounts reveal it, and a metamodule
# mount on top would serve the same payload meanwhile.  post-mount.sh
# re-asserts visibility when a manager mount shadows this bind.
#
# skip_mount is never used: the payload stays canonical for every manager.

MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=$(pwd)

grep -q '^KernelSU_Module=true$' "$MODDIR/module.prop" 2>/dev/null || exit 0

sh "$MODDIR/turnip-provision.sh"
exit 0
