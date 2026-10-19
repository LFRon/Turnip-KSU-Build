#!/system/bin/sh
# Runs after the manager's mount stage finished (on KernelSU the metamodule's
# metamount.sh has run at this point; that stage is executed unconditionally,
# v3.3.1 init_event.rs -> run_stage("post-mount")).
#
# If the payload is still not the live HAL -- no metamodule, a metamodule that
# mounted nothing, a mount tree that does not carry this payload, or a manager
# mount that shadowed the post-fs-data bind -- bind it on top so every app
# sees Turnip while modules are mounted.  The bind created in post-fs-data.sh
# stays underneath and is the one that survives per-app module unmounting (see
# that script's header).
#
# Same single criterion as post-fs-data.sh: the dedicated module.prop
# attribute stamped by customize.sh.

MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=$(pwd)

grep -q '^KernelSU_Module=true$' "$MODDIR/module.prop" 2>/dev/null || exit 0

sh "$MODDIR/turnip-provision.sh"
exit 0
