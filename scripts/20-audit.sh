#!/usr/bin/env bash
# Phase 20: regression guard for the built HAL.
#   * no framework-private or QTI-private gralloc symbols (parity with the
#     original CI guard);
#   * DT_NEEDED set must stay on the audited whitelist.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../config.sh"
source "$HERE/lib.sh"

hal="${HAL:-$hal_artifact}"
[ -f "$hal" ] || die "HAL not found: $hal (build mesa first or pass --hal)"
need_cmd strings
need_cmd readelf

log "strings audit (private gralloc references)"
# Allowed by design: NDK libraries, the AIMapper stable-C interface and the
# HIDL IMapper@4.0 passthrough contract.  Forbidden: framework-private libui,
# vendor-private gralloc helpers, QTI internal C++ ABI.
if strings "$hal" | grep -qE "$forbidden_symbols"; then
    die "HAL references framework or vendor-private gralloc symbols"
fi
info "no private gralloc symbols"

log "DT_NEEDED audit"
mapfile -t needed < <(LC_ALL=C readelf -d "$hal" | sed -n '/NEEDED/ s/.*\[\(.*\.so\)\].*/\1/p' | sort)
mapfile -t expect < <(printf '%s\n' "${expected_needed[@]}" | sort)
if [ "${needed[*]}" != "${expect[*]}" ]; then
    printf 'unexpected DT_NEEDED set:\n  got:  %s\n  want: %s\n' "${needed[*]}" "${expect[*]}" >&2
    die "DT_NEEDED whitelist mismatch"
fi
info "DT_NEEDED whitelist ok (${#needed[@]} entries)"
