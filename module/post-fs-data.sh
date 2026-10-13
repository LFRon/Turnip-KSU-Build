#!/system/bin/sh
# Turnip / KernelSU adapter: self-contained, no metamodule involved.
#
# KernelSU mounts no modules by itself.  Mounts belong to an optional
# metamodule, and the kernel umount list only detaches mount points that were
# registered in it (a metamodule-only API).  A plain bind mount created here,
# in the global mount namespace and before any metamodule mount script runs,
# is registered nowhere, so it survives per-app module unmounting and keeps
# the HAL visible to every process -- a magic-mount style single file bind
# issued straight to the kernel.
#
# Only baseline facilities are used (mount --bind, tmpfs, chcon and toybox
# shell tools), so any Snapdragon device that can run KernelSU is covered.
# The standard skip_mount marker keeps metamodules from staging this module.
# A covering overlay (another module's content in the same vendor directory)
# would shadow the bind and serve the stock HAL, so a background top-up bind
# waits for such a mount and re-asserts the HAL above it; detaching the
# overlay later (per-app module unmounting) reveals the original bind again.
# Magisk and other managers mount this module natively and stay untouched.

MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=$(pwd)

LOG="$MODDIR/post-fs-data.log"
HAL="vulkan.adreno.so"
STAGE_DIR="/dev/.vendor_hal"
DEFAULT_CTX="u:object_r:same_process_hal_file:s0"

log() { echo "$(date +%H:%M:%S) $*" >>"$LOG" 2>/dev/null; }

# KernelSU metamodules honour the standard skip_mount flag and must not stage
# this module; the HAL is provided by the binds below.  Install time creates
# the marker too; this re-asserts it before the metamodule mount stage runs.
if [ "$KSU" = "true" ]; then
	[ -e "$MODDIR/skip_mount" ] || { : > "$MODDIR/skip_mount" 2>/dev/null; log "created skip_mount"; }
elif [ -e "$MODDIR/skip_mount" ]; then
	# Stale flag from an earlier KernelSU install: the current manager has
	# already skipped its own mount for this boot, so self-mount now and drop
	# the flag; the next boot returns to the native manager mount.
	log "stale skip_mount under non-KernelSU manager; self-mounting this boot"
	rm -f "$MODDIR/skip_mount" 2>/dev/null
else
	log "KernelSU not active (KSU='$KSU'); manager mount in use; skip"
	exit 0
fi

read_ctx() { ls -Z "$1" 2>/dev/null | awk '{print $1}' | head -n 1; }

# True when the mount at $1 is one of ours (staged or module-path source).
own_bind() {
	awk -v d="$1" '$5 == d && ($4 ~ /^\/\.vendor_hal\// || $4 ~ /\/modules\//) { f = 1 } END { exit !f }' /proc/self/mountinfo 2>/dev/null
}

bind_hal() {
	src="$1"; dst="$2"
	[ -f "$src" ] || { log "skip $dst: source missing"; return 0; }
	[ -e "$dst" ] || { log "skip $dst: target missing"; return 0; }

	if own_bind "$dst"; then
		log "already bound: $dst"
		return 0
	fi

	# The label a HAL at $dst is expected to carry: read it from the real
	# vendor file (this runs before metamodule mount scripts, so the vendor
	# tree is still stock), with the standard Android label as fallback.
	ctx=$(read_ctx "$dst")
	case "$ctx" in u:object_r:*file:s0) ;; *) ctx="$DEFAULT_CTX" ;; esac
	[ "$ctx" = "u:object_r:system_file:s0" ] && ctx="$DEFAULT_CTX"

	# Stage a copy on tmpfs so per-app mountinfo shows a plain tmpfs file
	# instead of any module or root-tool path.
	staged="$STAGE_DIR/$HAL"
	mkdir -m 0700 -p "$STAGE_DIR" 2>/dev/null
	if cp -f "$src" "$staged" 2>/dev/null && chmod 0644 "$staged" 2>/dev/null &&
		chcon "$ctx" "$staged" 2>/dev/null && [ "$(read_ctx "$staged")" = "$ctx" ]; then
		bind_src="$staged"
	else
		rm -f "$staged" 2>/dev/null
		chcon "$ctx" "$src" 2>/dev/null
		bind_src="$src"
		log "staging unavailable; binding module path directly"
	fi

	if mount --bind "$bind_src" "$dst" 2>>"$LOG"; then
		log "bound $dst <- $bind_src ($ctx)"
	else
		log "bind failed: $dst"
	fi
	return 0
}

# Late top-up for a covering overlay.  A metamodule mount script runs right
# after this stage; if it mounts an overlay over the HAL directory (content
# from other modules), that overlay's lower layer holds the stock HAL and
# shadows the bind above.  This waits for the path to stop resolving to the
# staged file and re-binds it on top, so the path resolves to Turnip both
# while the overlay is up and after it is detached per app.  It runs in the
# background to keep the boot stage fast and exits silently on timeout.
topup() {
	dst="$1"; staged="$STAGE_DIR/$HAL"
	[ -f "$staged" ] || return 0
	[ -e "$dst" ] || return 0
	tries=0
	while [ "$tries" -lt 40 ]; do
		cur=$(stat -c %i "$staged" 2>/dev/null)
		at=$(stat -c %i "$dst" 2>/dev/null)
		if [ -n "$cur" ] && [ -n "$at" ] && [ "$cur" != "$at" ]; then
			if mount --bind "$staged" "$dst" 2>>"$LOG"; then
				log "top-up bound: $dst"
			else
				log "top-up bind failed: $dst"
			fi
			return 0
		fi
		sleep 0.5 2>/dev/null || sleep 1
		tries=$((tries + 1))
	done
	return 0
}

bind_hal "$MODDIR/system/vendor/lib64/hw/$HAL" "/vendor/lib64/hw/$HAL"
bind_hal "$MODDIR/system/vendor/lib/hw/$HAL" "/vendor/lib/hw/$HAL"

( topup "/vendor/lib64/hw/$HAL" ) >>"$LOG" 2>&1 &
( topup "/vendor/lib/hw/$HAL" ) >>"$LOG" 2>&1 &

exit 0
