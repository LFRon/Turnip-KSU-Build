# Turnip-KSU-Build

Build repository for the Turnip (Mesa freedreno Vulkan) **Magisk / KernelSU**
module and its adrenotools variant.

The layout is deliberately small and modular:

| Path | Role |
|------|------|
| `module/` | module payload (zip root), shipped **verbatim** — real, reviewable, shellcheck-able scripts |
| `scripts/` | one file per build phase |
| `config.sh` | the only place paths and knobs live (environment-overridable) |
| `build.sh` | thin entry point |
| `turnip_workdir/` | download/cache slots (`Android-NDK/`, `mesa-source/`, `archives/`), staging, logs (gitignored) |
| `out/` | `turnip.zip`, `turnip_adrenotools.zip`, `update.json`, `SHA256SUMS`, `build-info.json` (gitignored) |

## Requirements

`meson ninja patchelf zip unzip curl git` are required on PATH
(`./build.sh deps` verifies them); `ccache flex bison glslang
glslangValidator pip` are recommended and only reported as warnings (meson
drops a missing ccache wrapper on its own).  The Python `mako` module is
installed automatically when missing.

## Quick start

```sh
./build.sh                 # all phases: deps -> mesa -> audit -> module -> adrenotools -> update-json
```

Artifacts land in `out/`.  `build.sh` never downloads anything twice: see
**Caching** below.

## Phases and flags

```sh
./build.sh [all|deps|mesa|audit|module|adrenotools|update-json|lint|clean|clean-all]
```

| Flag | Effect |
|------|--------|
| `--mesa-dir <dir>` | build an existing mesa tree; it is used untouched and **never fetched** |
| `--mesa-rev <rev>` | pin the mesa checkout to a revision (reproducible builds) |
| `--update-mesa` | refresh the cached checkout (clean tree required; full trees fast-forward, shallow trees are force-updated to the branch tip) |
| `--force-fetch` | re-download cached archives (NDK etc.) |
| `--hal <file>` | use a prebuilt `libvulkan_freedreno.so` (skips the mesa phase) |
| `--out <dir>` / `--workdir <dir>` | override output / cache directories |
| `-j, --jobs <n>` | ninja parallelism |

## Caching rules

Everything needed from the network lives under `turnip_workdir/` in
**version-agnostic slots** and is reused if present and verified:

* `Android-NDK.zip` (archive) → `Android-NDK/` (extracted tree): verified
  against a pinned `NDK_SHA256` when set, otherwise the upstream `.sha1`
  sidecar (falling back to an archive integrity test if the sidecar is
  unreachable) plus a `unzip -t` test; the tree is re-unpacked only when the
  archive hash changes (`.unpacked` stamp).  Bumping `NDKVER` simply
  re-verifies and refreshes these slots in place.
* `mesa-source/`: the cached checkout, pulled with `git clone --depth=1`
  (shallow; set `MESA_CLONE_DEPTH=0` for a full clone); used as-is, only
  touched by `--update-mesa` or `--mesa-rev`.
  Reusing an existing checkout instead of cloning works by linking it into
  the slot — `ln -s ../../mesa-main turnip_workdir/mesa-source` — and the
  same trick applies to the NDK slot (`Android-NDK/`).
* Downloads go to `*.part` and are atomically renamed, so an interrupted
  fetch never leaves a half archive behind.

Meson cross/native files (`android-aarch64.txt`, `native.txt`) are generated
from `config.sh` (`SDKVER`, NDK directory), stashed under `turnip_workdir/`
and copied into the source tree **only while it is being configured and
compiled**; they are removed again afterwards so the mesa checkout stays
clean.  The copies keep their stashed mtimes, so unchanged files do not make
ninja re-run meson — steady-state builds go straight to ninja (sub-second
no-op).

`./build.sh clean` removes the staging directories and `out/`; `clean-all`
additionally removes every cache slot under `turnip_workdir/` (symlinked
source trees are never touched — only the links themselves are removed).

## Maintainer duties

* Bump `version=` / `versionCode=` in `module/module.prop` (monotonically
  increasing) and note it in `changelog.md`.  That is the only manual edit
  needed for a release.
* `out/update.json` is generated from `module.prop`, so both stay in sync.
* The `mesa` source is abstracted in `config.sh` (`mesasrc`, `mesabranch`);
  it defaults to the maintained fork
  `https://github.com/LFRon/Turnip-Enhanced.git` (branch `main`).

## Releasing

Upload to the `github_run` release channel (the URL `module.prop` points at):

```sh
gh release upload github_run out/turnip.zip out/turnip_adrenotools.zip \
    out/update.json changelog.md --clobber
```

`update.json` references `RELEASE_BASE` from `config.sh`; adjust it if the
channel moves.

## Payload notes

`module/` is shipped verbatim.  It is KernelSU-first: `post-fs-data.sh`
manages the `skip_mount` marker, stages the HAL on tmpfs and binds it into
the vendor HAL path (with a background top-up for covering overlayfs
mounts); `customize.sh` fixes the SELinux labels and the marker at install
time; `uninstall.sh` cleans up.  Magisk and APatch fall back to their native
mount path automatically.  The four HAL paths cover both the `system/vendor`
tree (Magisk `system/` overlay) and the promoted top-level `vendor/` tree
(metamodule layouts).
