# Turnip-KSU-Build: single source of configuration.
# Every variable below can be overridden from the environment or from
# build.sh flags; nothing else in the repository hardcodes paths.

# --- repository layout ---------------------------------------------------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$REPO_DIR/module"
SCRIPTS_DIR="$REPO_DIR/scripts"
WORKDIR="${WORKDIR:-$REPO_DIR/turnip_workdir}"   # downloads, caches, staging
OUTDIR="${OUTDIR:-$REPO_DIR/out}"                # build artifacts

# --- mesa source (abstracted like the original builder) -------------------
# Defaults to the maintained fork; point MESASRC anywhere for experiments.
mesasrc="${MESASRC:-https://github.com/LFRon/Turnip-Enhanced.git}"
mesabranch="${MESABRANCH:-main}"
# Optional revision pin for reproducible builds (empty = branch head).
MESA_REV="${MESA_REV:-}"
# Shallow clone depth (default 1).  Set to 0 or empty for a full clone.
# The source is always cloned with git (never downloaded as a zip archive).
MESA_CLONE_DEPTH="${MESA_CLONE_DEPTH:-1}"
# Checkout/build tree; --mesa-dir overrides it (external tree is never
# fetched).  The directory name is version-agnostic and reused across mesa
# revisions; --update-mesa/--mesa-rev refresh it in place.
MESA_DIR="${MESA_DIR:-$WORKDIR/mesa-source}"

# --- Android NDK ----------------------------------------------------------
# Unified, version-agnostic cache slots: bumping NDKVER re-verifies the
# existing archive and re-unpacks in place only when the content changed;
# the mesa build dir is additionally recreated when the toolchain changes.
ndkver="${NDKVER:-android-ndk-r30}"
ndkurl="${NDKURL:-https://dl.google.com/android/repository/${ndkver}-linux.zip}"
ndkzip="$WORKDIR/archives/Android-NDK.zip"
# NDK_DIR may point at an already extracted NDK root (then nothing is
# downloaded); NDK_BIN defaults to the toolchain bin directory inside it.
ndkdir="${NDK_DIR:-$WORKDIR/Android-NDK}"
ndkbin="${NDK_BIN:-$ndkdir/toolchains/llvm/prebuilt/linux-x86_64/bin}"
# Pinned archive checksum (sha256): verified after every download and on
# every extraction; keep in sync with NDKVER.  Google's .sha1 sidecar is 404
# for r30, so this pin is the primary integrity source (empty = sidecar plus
# archive integrity test).
NDK_SHA256="${NDK_SHA256:-753611f410d002cfcd3f3dc2ef49aad532089d3180b436c060a90bf0fcb64df2}"

# --- target / toolchain ---------------------------------------------------
sdkver="${SDKVER:-35}"   # load-bearing: stable-C gralloc backend + EFR gating

# --- module payload -------------------------------------------------------
module_id="turnip"       # must match module/module.prop
hal_name="vulkan.adreno.so"
# Canonical module layout: the manager maps system/vendor onto /vendor
# (KernelSU also auto-creates the top-level vendor symlink); never ship a
# real top-level vendor/ tree yourself.
hal_paths=(
    "system/vendor/lib64/hw"
    "system/vendor/lib/hw"
)
adrenotools_name="vulkan.freedreno.so"

# --- audit expectations ---------------------------------------------------
# Private gralloc access is banned outright (see the original CI guard).
forbidden_symbols='libui|GraphicBufferMapper|_ZN7gralloc|libgrallocutils|_ZN10qtigralloc|_ZN7qtigralloc|qdMetaData'
expected_needed=(
    "libhardware.so"
    "liblog.so"
    "libnativewindow.so"
    "libsync.so"
    "libm.so"
    "libz.so"
    "libdl.so"
    "libc.so"
)

# --- release channel (module.prop updateJson + update.json zipUrl) --------
RELEASE_BASE="${RELEASE_BASE:-https://github.com/LFRon/Turnip-KSU-Build/releases/download/github_run}"

# --- derived build locations ----------------------------------------------
mesabuild_dir="${MESABUILD_DIR:-$MESA_DIR/build-android-aarch64}"
hal_artifact="$mesabuild_dir/src/freedreno/vulkan/libvulkan_freedreno.so"

# --- runtime flags (set by build.sh, harmless defaults for direct use) ----
force_fetch="${force_fetch:-0}"
update_mesa="${update_mesa:-0}"
mesa_dir_external="${mesa_dir_external:-0}"
JOBS="${JOBS:-}"
HAL="${HAL:-}"
