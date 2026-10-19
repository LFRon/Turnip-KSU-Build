#!/system/bin/sh
# Turnip self-provisioning helper (KernelSU).
#
# The canonical system/vendor payload stays the single source of truth for
# managers that mount it (Magisk, KernelSU metamodules).  On top of that the
# module always serves the HAL itself on KernelSU:
#
#   * mounting with a plain bind keeps the mount unmarked (no source=KSU), so
#     KernelSU's per-app "unmount modules" feature does not detach it -- this
#     is what keeps Turnip alive with "unmount modules by default" enabled;
#   * it is also the only supply path when no metamodule is installed, since
#     KernelSU >= 3 mounts nothing by itself.
#
# Idempotent: when the live HAL already is the payload (metamodule mount,
# injection, or a previous run) nothing is touched, so calling it from
# post-fs-data.sh and post-mount.sh is safe and cheap.

MODDIR=${MODDIR:-}
if [ -z "$MODDIR" ]; then
    MODDIR=${0%/*}
    [ -d "$MODDIR" ] || MODDIR=$(pwd)
fi
LOG="$MODDIR/provision.log"
HAL=vulkan.adreno.so
DEFAULT_CTX=u:object_r:same_process_hal_file:s0

log() { echo "$(date '+%m-%d %H:%M:%S') $*" >>"$LOG" 2>/dev/null; }

# toybox and busybox both print the SELinux context in `ls -Z`, but not in the
# same column (toybox: 5th field, after mode/links/owner/group).  Extract it by
# pattern so the reader cannot silently pick up the mode string instead.
read_ctx() { ls -Z "$1" 2>/dev/null | tr ' ' '\n' | grep -m1 '^u:object_r:'; }

provision() {
    arch=$1
    dst="/vendor/$arch/hw/$HAL"
    src="$MODDIR/system/vendor/$arch/hw/$HAL"
    # The KernelSU installer (handle_partition) may move the payload to a real
    # top-level vendor/ and leave system/vendor as a symlink to it; both
    # layouts resolve the path above, and the fallback covers a reshaped dir.
    [ -f "$src" ] || src="$MODDIR/vendor/$arch/hw/$HAL"
    [ -f "$src" ] || return 0
    [ -e "$dst" ] || return 0

    if cmp -s "$dst" "$src" 2>/dev/null; then
        log "$arch: payload already live at $dst (served by the manager); nothing to do"
        return 0
    fi

    # A bind mount serves the source inode's xattr label to every process
    # (mount points carry no label of their own), so the payload must wear the
    # vendor HAL label.  customize.sh sets it at install time; re-assert it
    # here for managers whose set_perm ignored the context argument.
    ctx=$(read_ctx "$src")
    case "$ctx" in
        u:object_r:*hal_file:s0) ;;
        *)
            chcon "$DEFAULT_CTX" "$src" 2>/dev/null
            ctx=$(read_ctx "$src")
            log "$arch: relabelled payload ($ctx)"
            ;;
    esac

    if mount --bind "$src" "$dst" 2>/dev/null; then
        if cmp -s "$dst" "$src" 2>/dev/null; then
            log "$arch: bind $dst <- $src (ctx=$ctx)"
        else
            log "$arch: bind reported success but the content differs"
        fi
    else
        log "$arch: bind mount failed for $dst"
    fi
    return 0
}

for arch in lib64 lib; do
    provision "$arch"
done

exit 0
