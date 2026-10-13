#!/usr/bin/env bash
# Shared helpers for every phase script (sourced, never executed directly).

set -euo pipefail

green='\033[0;32m'
red='\033[0;31m'
yellow='\033[0;33m'
nocolor='\033[0m'

log()  { printf '%b[build]%b %s\n' "$yellow" "$nocolor" "$*"; }
info() { printf '%b[ ok ]%b %s\n' "$green" "$nocolor" "$*"; }
warn() { printf '%b[warn]%b %s\n' "$yellow" "$nocolor" "$*" >&2; }
die()  { printf '%b[fail]%b %s\n' "$red" "$nocolor" "$*" >&2; exit 1; }

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

# --- verified download cache ---------------------------------------------
# verify_file <file> [sha256] [sha1_url]
# Uses the pinned sha256 when given, otherwise the upstream .sha1 sidecar;
# zip archives are additionally integrity-tested.
verify_file() {
    local f="$1" sha256="${2:-}" sha1url="${3:-}" want
    [ -s "$f" ] || return 1
    if [ -n "$sha256" ]; then
        printf '%s  %s\n' "$sha256" "$f" | sha256sum -c - >/dev/null 2>&1 || return 1
    elif [ -n "$sha1url" ]; then
        if want="$(curl -fsL "$sha1url" | tr -d '[:space:]')" && [ -n "$want" ]; then
            printf '%s  %s\n' "$want" "$f" | sha1sum -c - >/dev/null 2>&1 || return 1
        else
            warn "checksum sidecar unavailable ($sha1url); falling back to an archive integrity test"
        fi
    fi
    case "$f" in
        *.zip) unzip -tq "$f" >/dev/null 2>&1 || return 1 ;;
    esac
    return 0
}

# fetch_cached <url> <dest> [sha256] [sha1_url]
# An existing verified archive is reused and never re-downloaded.
fetch_cached() {
    local url="$1" dest="$2" sha256="${3:-}" sha1url="${4:-}"
    mkdir -p "$(dirname "$dest")"
    if [ -f "$dest" ]; then
        if [ "$force_fetch" != "1" ] && verify_file "$dest" "$sha256" "$sha1url"; then
            info "archive cache hit (verified): $dest"
            return 0
        fi
        if [ "$force_fetch" != "1" ]; then
            warn "cached archive failed verification, re-downloading: $dest"
        fi
    fi
    log "downloading: $url"
    rm -f "$dest.part"
    curl -fL --retry 3 --retry-delay 2 -o "$dest.part" "$url" || die "download failed: $url"
    verify_file "$dest.part" "$sha256" "$sha1url" || { rm -f "$dest.part"; die "verification failed: $url"; }
    mv "$dest.part" "$dest"
    info "downloaded and verified: $dest"
}

# extract_zip_cached <zip> <dest_dir> <sentinel_relpath>
# Re-extracts only when the archive changed or the tree is incomplete.
extract_zip_cached() {
    local zip="$1" dest="$2" sentinel="$3" stamp top
    stamp="$(sha256sum "$zip" | awk '{print $1}')"
    if [ -e "$dest/.unpacked" ] && [ "$(cat "$dest/.unpacked" 2>/dev/null)" = "$stamp" ] \
       && [ -e "$dest/$sentinel" ]; then
        info "extract cache hit: $dest"
        return 0
    fi
    log "extracting: $zip -> $dest"
    rm -rf "$dest" "$dest.tmp"
    unzip -q "$zip" -d "$dest.tmp" || die "unzip failed: $zip"
    top="$(find "$dest.tmp" -mindepth 1 -maxdepth 1 | head -n 1)"
    [ -n "$top" ] || die "extraction produced no entries: $zip"
    if [ -d "$top" ] && [ "$(find "$dest.tmp" -mindepth 1 -maxdepth 1 | wc -l)" -eq 1 ]; then
        mv "$top" "$dest"
        rm -rf "$dest.tmp"
    else
        # Multi-root archives are kept as-is; inner sentinel paths may not
        # resolve, in which case they simply re-extract on every run.
        mv "$dest.tmp" "$dest"
    fi
    printf '%s\n' "$stamp" > "$dest/.unpacked"
    info "extracted: $dest"
}

# --- artifact reporting ---------------------------------------------------
# report_artifacts: write out/SHA256SUMS and out/build-info.json.
report_artifacts() {
    local module_version module_code mesa_rev mesa_version sep="" f name sha size
    [ -d "$OUTDIR" ] || return 0

    ( cd "$OUTDIR" && sha256sum ./*.zip 2>/dev/null ) > "$OUTDIR/SHA256SUMS" || true
    [ -s "$OUTDIR/SHA256SUMS" ] || rm -f "$OUTDIR/SHA256SUMS"

    module_version="$(sed -n 's/^version=//p' "$MODULE_DIR/module.prop" | head -n 1)"
    module_code="$(sed -n 's/^versionCode=//p' "$MODULE_DIR/module.prop" | head -n 1)"
    mesa_rev=""
    mesa_version=""
    if [ -d "$MESA_DIR/.git" ]; then
        mesa_rev="$(git -C "$MESA_DIR" rev-parse HEAD 2>/dev/null || true)"
    fi
    [ -f "$MESA_DIR/VERSION" ] && mesa_version="$(cat "$MESA_DIR/VERSION")"

    {
        printf '{\n'
        printf '  "date": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf '  "mesa": { "src": "%s", "branch": "%s", "rev": "%s", "version": "%s" },\n' \
               "$mesasrc" "$mesabranch" "$mesa_rev" "$mesa_version"
        printf '  "module": { "version": "%s", "versionCode": %s },\n' \
               "$module_version" "${module_code:-0}"
        printf '  "artifacts": {'
        for f in "$OUTDIR"/*.zip; do
            [ -e "$f" ] || continue
            name="$(basename "$f")"
            sha="$(sha256sum "$f" | awk '{print $1}')"
            size="$(stat -c %s "$f")"
            printf '%s\n    "%s": { "sha256": "%s", "size": %s }' "$sep" "$name" "$sha" "$size"
            sep=","
        done
        printf '\n  }\n}\n'
    } > "$OUTDIR/build-info.json"
    info "wrote $OUTDIR/SHA256SUMS and $OUTDIR/build-info.json"
}
