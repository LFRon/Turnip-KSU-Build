# Changelog

## Unreleased

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
