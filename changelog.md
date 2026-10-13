# Changelog

## Unreleased

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
