#!/usr/bin/env bash
# Phase 05 (optional): static analysis of the build scripts and the payload.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../config.sh"
source "$HERE/lib.sh"

if ! command -v shellcheck >/dev/null 2>&1; then
    warn "shellcheck not installed; lint skipped"
    exit 0
fi

log "shellcheck: module payload"
shellcheck -x "$MODULE_DIR"/*.sh

log "shellcheck: build scripts"
shellcheck -x "$SCRIPTS_DIR"/*.sh "$REPO_DIR/build.sh" "$REPO_DIR/config.sh"

info "lint clean"
