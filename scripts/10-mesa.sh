#!/usr/bin/env bash
# Phase 10: resolve the mesa source tree and build libvulkan_freedreno.so.
#
# Caching rules:
#   * an existing checkout under turnip_workdir is reused as-is (no fetch);
#   * --update-mesa refreshes it (fast-forward only, clean tree required);
#   * --mesa-rev pins it to a revision;
#   * --mesa-dir uses an external tree untouched (never fetched);
#   * the NDK archive/extract under turnip_workdir is verified and reused;
#   * cross/native files are stashed in turnip_workdir and copied into the
#     source tree only while configuring/compiling (removed afterwards, so
#     the tree stays clean); meson is (re)configured only when their content
#     changed and the copies keep their stashed mtimes otherwise.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../config.sh"
source "$HERE/lib.sh"

# --- mesa tree ------------------------------------------------------------
depth_args=()
depth_desc="full"
if [ -n "$MESA_CLONE_DEPTH" ] && [ "$MESA_CLONE_DEPTH" != "0" ]; then
    depth_args=(--depth "$MESA_CLONE_DEPTH")
    depth_desc="depth $MESA_CLONE_DEPTH"
fi

if [ "$mesa_dir_external" = "1" ]; then
    info "external mesa tree (never fetched): $MESA_DIR"
elif [ -d "$MESA_DIR" ]; then
    if [ -d "$MESA_DIR/.git" ]; then
        if [ -n "$MESA_REV" ]; then
            log "pinning mesa to $MESA_REV"
            git -C "$MESA_DIR" fetch "${depth_args[@]}" origin "$MESA_REV" || die "git fetch failed"
            git -C "$MESA_DIR" checkout --detach "$MESA_REV" || die "git checkout failed"
        elif [ "$update_mesa" = "1" ]; then
            if [ -n "$(git -C "$MESA_DIR" status --porcelain)" ]; then
                warn "mesa tree is dirty; skipping --update-mesa"
            else
                log "updating mesa ($mesabranch)"
                if [ "$(git -C "$MESA_DIR" rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then
                    git -C "$MESA_DIR" fetch --depth=1 origin "$mesabranch" || die "git fetch failed"
                else
                    git -C "$MESA_DIR" fetch "${depth_args[@]}" origin "$mesabranch" || die "git fetch failed"
                fi
                git -C "$MESA_DIR" checkout "$mesabranch" || die "git checkout failed"
                git -C "$MESA_DIR" merge --ff-only "origin/$mesabranch" \
                    || warn "not a fast-forward; keeping the current tree"
            fi
        fi
        info "mesa cache hit: $MESA_DIR @ $(git -C "$MESA_DIR" rev-parse --short HEAD)"
        [ -n "$(git -C "$MESA_DIR" status --porcelain)" ] \
            && warn "mesa tree has local modifications; building as-is"
    else
        info "using existing mesa tree (not a git checkout): $MESA_DIR"
    fi
else
    if [ -n "$MESA_REV" ]; then
        log "cloning $mesasrc ($mesabranch, $depth_desc, rev $MESA_REV)"
        git clone "${depth_args[@]}" --branch "$mesabranch" "$mesasrc" "$MESA_DIR" \
            || die "git clone failed"
        git -C "$MESA_DIR" fetch "${depth_args[@]}" origin "$MESA_REV" \
            || die "git fetch of $MESA_REV failed (retry with MESA_CLONE_DEPTH=0 for a full clone)"
        git -C "$MESA_DIR" checkout --detach "$MESA_REV" || die "git checkout failed"
    else
        log "cloning $mesasrc ($mesabranch, $depth_desc)"
        git clone "${depth_args[@]}" --branch "$mesabranch" "$mesasrc" "$MESA_DIR" \
            || die "git clone failed"
    fi
fi

[ -f "$MESA_DIR/meson.build" ] || die "not a mesa source tree: $MESA_DIR"

# A build dir configured for a different source path cannot be reused (meson
# stores absolute paths); recreate it in place so a moved checkout heals.
if [ -f "$mesabuild_dir/build.ninja" ] \
   && ! grep -aqF "$(cd "$MESA_DIR" && pwd -P)" "$mesabuild_dir/meson-private/coredata.dat"; then
    warn "build dir was configured for a different source path; recreating: $mesabuild_dir"
    rm -rf "$mesabuild_dir"
fi

# --- NDK (verified download cache) ---------------------------------------
if [ -d "$ndkbin" ] && [ "$force_fetch" != "1" ]; then
    info "ndk cache hit: $ndkdir"
else
    fetch_cached "$ndkurl" "$ndkzip" "$NDK_SHA256" "${ndkurl}.sha1"
    extract_zip_cached "$ndkzip" "$ndkdir" "toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
fi
[ -x "$ndkbin/clang" ] || die "NDK toolchain missing under: $ndkbin"

# --- cross/native files (stashed in the workdir; copied into the source ----
# tree only for configure/compile and removed again afterwards) ------------
mkdir -p "$WORKDIR"
tmp_android="$WORKDIR/xf.tmp.android-aarch64.txt"
tmp_native="$WORKDIR/xf.tmp.native.txt"
xf_android="$WORKDIR/xf.android-aarch64.txt"
xf_native="$WORKDIR/xf.native.txt"

cat > "$tmp_android" <<EOF
[binaries]
ar = '$ndkbin/llvm-ar'
c = ['ccache', '$ndkbin/aarch64-linux-android$sdkver-clang']
cpp = ['ccache', '$ndkbin/aarch64-linux-android$sdkver-clang++', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '--start-no-unused-arguments', '-static-libstdc++', '--end-no-unused-arguments']
c_ld = '$ndkbin/ld.lld'
cpp_ld = '$ndkbin/ld.lld'
strip = '$ndkbin/aarch64-linux-android-strip'
pkg-config = ['env', 'PKG_CONFIG_LIBDIR=$ndkbin/pkg-config', '/usr/bin/pkg-config']

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'
EOF

cat > "$tmp_native" <<'EOF'
[build_machine]
c = ['ccache', 'clang']
cpp = ['ccache', 'clang++']
ar = 'llvm-ar'
strip = 'llvm-strip'
c_ld = 'ld.lld'
cpp_ld = 'ld.lld'
system = 'linux'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOF

need_reconfigure=0
if [ "$force_fetch" = "1" ] || [ ! -f "$mesabuild_dir/build.ninja" ]; then
    need_reconfigure=1
fi
if ! cmp -s "$tmp_android" "$xf_android" || ! cmp -s "$tmp_native" "$xf_native"; then
    mv -f "$tmp_android" "$xf_android"
    mv -f "$tmp_native" "$xf_native"
    need_reconfigure=1
else
    rm -f "$tmp_android" "$tmp_native"
fi

# Restore with preserved mtimes right before building: identical copies do
# not look newer than build.ninja, so ninja does not re-run meson.
cp -p "$xf_android" "$MESA_DIR/android-aarch64.txt"
cp -p "$xf_native" "$MESA_DIR/native.txt"

# The files only live in the source tree while the build runs; the EXIT trap
# also covers failures.
cleanup_xf() { rm -f "$MESA_DIR/android-aarch64.txt" "$MESA_DIR/native.txt"; }
trap cleanup_xf EXIT

if [ "$need_reconfigure" = "0" ]; then
    info "cross/native files unchanged; skipping meson setup"
fi

# Host tools resolve through the caller's PATH; the target compilers are
# always the NDK toolchain, referenced by absolute path in the cross file.
export CC=clang CXX=clang++ AR=llvm-ar RANLIB=llvm-ranlib
export STRIP=llvm-strip OBJDUMP=llvm-objdump OBJCOPY=llvm-objcopy
export LDFLAGS="-fuse-ld=lld"

# --- configure (only when needed) -----------------------------------------
if [ "$need_reconfigure" = "1" ]; then
    meson_opts=(
        "$mesabuild_dir"
        --cross-file "android-aarch64.txt"
        --native-file "native.txt"
        -Dbuildtype=release
        -Dplatforms=android
        -Dplatform-sdk-version="$sdkver"
        -Dandroid-stub=true
        -Dgallium-drivers=
        -Dvulkan-drivers=freedreno
        -Dvulkan-beta=true
        -Dfreedreno-kmds=kgsl
        -Dstrip=true
        -Degl=disabled
    )

    cd "$MESA_DIR"
    if [ -f "$mesabuild_dir/build.ninja" ]; then
        log "reconfiguring build files (meson setup --reconfigure)"
        meson setup --reconfigure "${meson_opts[@]}" &> "$WORKDIR/meson_log" \
            || { tail -n 40 "$WORKDIR/meson_log"; die "meson setup failed (log: $WORKDIR/meson_log)"; }
    else
        log "generating build files (meson setup)"
        meson setup "${meson_opts[@]}" &> "$WORKDIR/meson_log" \
            || { tail -n 40 "$WORKDIR/meson_log"; die "meson setup failed (log: $WORKDIR/meson_log)"; }
    fi
fi

# --- compile --------------------------------------------------------------
ninja_args=(-C "$mesabuild_dir")
[ -n "$JOBS" ] && ninja_args+=(-j "$JOBS")
log "compiling"
ninja "${ninja_args[@]}" &> "$WORKDIR/ninja_log" \
    || { tail -n 60 "$WORKDIR/ninja_log"; die "ninja failed (log: $WORKDIR/ninja_log)"; }

[ -f "$hal_artifact" ] || die "build failed: $hal_artifact missing"
info "built: $hal_artifact ($(stat -c %s "$hal_artifact") bytes)"

cleanup_xf
trap - EXIT
