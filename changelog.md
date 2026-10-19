# Changelog

## Unreleased

- `module/`: the module now serves the HAL itself on KernelSU, so Turnip also
  works without a metamodule (KernelSU >= 3 mounts no module files by itself:
  v3.3.1 `init_event.rs` only executes a metamodule's `metamount.sh`) and with
  "unmount modules by default" enabled (that feature only detaches mounts
  marked `source=KSU`, and the module's plain bind carries no such marker).
  The single criterion is the dedicated attribute `KernelSU_Module=true`,
  stamped into `module.prop` by `customize.sh` on KernelSU installs only, so
  Magisk and every other manager keep mounting the canonical payload natively.
  New: `turnip-provision.sh` (idempotent bind provisioning with label
  re-assert), `post-fs-data.sh` (binds below any metamodule mount),
  `post-mount.sh` (re-asserts visibility after the manager's mount stage) and
  `uninstall.sh` (detaches exactly those binds).  `skip_mount` is still never
  set.  The old label reader used `ls -Z | awk '{print $1}'`, which returns the
  mode string on toybox (the context is the 5th field); contexts are now
  extracted by pattern.  `action.sh` reports the attribute, the metamodule,
  the supply state and the attached bind count, and the packer refuses a
  payload that lost the attribute or the provisioning scripts.
- NDK bumped to `android-ndk-r30` (archive SHA256 pinned in `config.sh`;
  Google's `.sha1` sidecar is 404 for r30), and the mesa build dir is now
  fingerprinted with the toolchain version (`.ndk-fingerprint`), recreated
  when it changes, so a version bump cannot silently reuse object files
  built by the previous clang.
- `module/`: replaced the KernelSU self-mount design with the canonical
  layout.  The payload is the standard `system/vendor` tree, mounts and
  injection are left to the installed metamodule (or Magisk), and
  `skip_mount` is never set (a stale marker is removed at install).
  `post-fs-data.sh` and `uninstall.sh` are gone; `action.sh` compares the
  live HAL with the payload.
- Repository created: modular build pipeline.
  - `module/` carries the payload verbatim (post-fs-data/customize/action/
    uninstall, module.prop, system.prop, META-INF).
  - Phase scripts (`scripts/00..50`) with verified download caching under
    `turnip_workdir/` and generated meson cross files.
  - `out/` artifacts: `turnip.zip`, `turnip_adrenotools.zip`, `update.json`,
    `SHA256SUMS`, `build-info.json`.
