# Changelog

## Unreleased

- Repository created: modular build pipeline.
  - `module/` carries the payload verbatim (post-fs-data/customize/action/
    uninstall, module.prop, system.prop, META-INF).
  - Phase scripts (`scripts/00..50`) with verified download caching under
    `turnip_workdir/` and generated meson cross files.
  - `out/` artifacts: `turnip.zip`, `turnip_adrenotools.zip`, `update.json`,
    `SHA256SUMS`, `build-info.json`.
