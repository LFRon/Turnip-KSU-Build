#!/usr/bin/env bash
# Turnip-KSU-Build: thin entry point.
#
#   ./build.sh [phase] [flags]
#
# Phases: all (default) | deps | mesa | audit | module | adrenotools |
#         update-json | lint | clean | clean-all
#
# Flags:  --mesa-dir <dir>   build an existing mesa tree (never fetched)
#         --mesa-rev <rev>   pin the mesa checkout to a revision
#         --update-mesa      refresh the cached mesa checkout first
#         --force-fetch      re-download cached archives
#         --hal <file>       use a prebuilt libvulkan_freedreno.so
#         --out <dir>        artifact directory (default: out/)
#         --workdir <dir>    cache/staging directory (default: turnip_workdir/)
#         -j, --jobs <n>     ninja parallelism

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

phase="all"
if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
    phase="$1"
    shift
fi

mesa_dir_external=0

while [ $# -gt 0 ]; do
    case "$1" in
        --mesa-dir)     MESA_DIR="$2"; mesa_dir_external=1; shift 2 ;;
        --mesa-rev)     MESA_REV="$2"; shift 2 ;;
        --update-mesa)  update_mesa=1; shift ;;
        --force-fetch)  force_fetch=1; shift ;;
        --hal)          HAL="$2"; shift 2 ;;
        --out)          OUTDIR="$2"; shift 2 ;;
        --workdir)      WORKDIR="$2"; shift 2 ;;
        -j|--jobs)      JOBS="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

export WORKDIR OUTDIR MESA_DIR MESA_REV update_mesa force_fetch JOBS HAL
export mesa_dir_external

source config.sh
source scripts/lib.sh

run_phase() {
    log "phase: $1"
    bash "$SCRIPTS_DIR/$1"
}

case "$phase" in
    all)
        run_phase 00-deps.sh
        run_phase 10-mesa.sh
        run_phase 20-audit.sh
        run_phase 30-pack-module.sh
        run_phase 40-pack-adrenotools.sh
        run_phase 50-update-json.sh
        report_artifacts
        ;;
    deps)         run_phase 00-deps.sh ;;
    mesa)         run_phase 10-mesa.sh ;;
    audit)        run_phase 20-audit.sh ;;
    module)       run_phase 30-pack-module.sh; report_artifacts ;;
    adrenotools)  run_phase 40-pack-adrenotools.sh; report_artifacts ;;
    update-json)  run_phase 50-update-json.sh; report_artifacts ;;
    lint)         run_phase 05-lint.sh ;;
    clean)
        rm -rf "$WORKDIR/pack-module" "$WORKDIR/pack-adrenotools" "$OUTDIR"
        info "removed staging and artifacts (caches kept)"
        ;;
    clean-all)
        rm -rf "$WORKDIR" "$OUTDIR"
        info "removed workdir and artifacts"
        ;;
    *)
        echo "unknown phase: $phase (try --help)" >&2
        exit 2
        ;;
esac
