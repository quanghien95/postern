#!/usr/bin/env bash
# check-topology-scrub.sh -- fail if HEAD re-advertises fleet topology (#527).
#
# The 2026-06-30 HEAD scrub (#177) stripped fleet hostnames and RFC1918 addresses
# from this public repo so we stop advertising role/port structure. A one-time
# cleanup with no check regresses (dischord came back in imap/bench/README.md on
# 2026-07-26; #528 scrubbed it again). This gate makes the next regression fail
# CI instead of waiting for the next audit.
#
# What is banned:
#   - Fleet box short hostnames (word-boundary match; the names alone, not the
#     public `fleet-chezmoi` repo name or `skyphusion.org` domains).
#   - RFC1918 private IPv4 (10/8, 172.16/12, 192.168/16). Loopback and RFC5737
#     documentation ranges (192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24) are fine.
#
# Usage:
#   bash .github/scripts/check-topology-scrub.sh
#   TOPOLOGY_SCRUB_ROOT=/path/to/fixture bash .github/scripts/check-topology-scrub.sh
#
# Exit 0 when clean, 1 when a hit is found, 2 on usage/tooling error.
set -euo pipefail

root="${TOPOLOGY_SCRUB_ROOT:-}"
if [[ -z "$root" ]]; then
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
cd "$root" || exit 2

# Short hostnames of the skyphusion fleet boxes. Keep this list equal to the
# boxes that would advertise topology if dropped into public docs; do not add
# common English words that are not box names.
# shellcheck disable=SC2016
host_re='\b(dischord|biafra|fugazi|jello|damaged|propagandhi|rancid|descendents|badbrains|fatmike|lagwagon|face2face|boon|watt)\b'

# RFC1918 dotted quads (not CIDR prose). Loopback and RFC5737 doc ranges are out of scope.
rfc1918_re='\b(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3})\b'

# Paths that must mention the banned tokens to implement this gate (the list + the
# positive-control fixture). Everything else is scanned.
# Use pathspec excludes that work with both `git grep` and plain `rg`.
exclude_pathspecs=(
  ':!.github/scripts/check-topology-scrub.sh'
  ':!.github/scripts/tests/check-topology-scrub.test.sh'
  ':!.github/scripts/tests/fixtures/topology-scrub'
  ':!package-lock.json'
  ':!**/package-lock.json'
  ':!**/*.lock'
  ':!**/*.png'
  ':!**/*.jpg'
  ':!**/*.woff'
  ':!**/*.woff2'
  ':!**/*.pdf'
)

hits=""
scan() {
  local label="$1"
  local pattern="$2"
  local out
  if [[ -d "$root/.git" ]] && git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    && [[ -z "${TOPOLOGY_SCRUB_ROOT:-}" ]]; then
    # Tracked files only: untracked local junk must not fail CI, and history is
    # deliberately out of scope (June scrub left history alone).
    out="$(git -C "$root" grep -nIE -e "$pattern" -- . "${exclude_pathspecs[@]}" 2>/dev/null || true)"
  else
    # Fixture / non-git mode for the unit suite.
    out="$(rg -n --no-heading -e "$pattern" \
      --glob '!.git/**' \
      --glob '!.github/scripts/check-topology-scrub.sh' \
      --glob '!.github/scripts/tests/check-topology-scrub.test.sh' \
      --glob '!.github/scripts/tests/fixtures/topology-scrub/**' \
      --glob '!package-lock.json' \
      --glob '!**/*.lock' \
      "$root" 2>/dev/null || true)"
  fi
  if [[ -n "$out" ]]; then
    hits+="--- ${label} ---"$'\n'"${out}"$'\n'
  fi
}

scan "fleet hostname" "$host_re"
scan "RFC1918 private address" "$rfc1918_re"

if [[ -n "$hits" ]]; then
  cat >&2 <<EOF
topology scrub failed (#527 / #177): tracked content re-advertises fleet topology.

${hits}
Replace fleet hostnames with a functional description (e.g. "crew dev box"), not a
substitute hostname. Use RFC5737 documentation ranges (192.0.2.0/24, 198.51.100.0/24,
203.0.113.0/24) when an example address is required. Loopback (127.0.0.0/8) is fine.
EOF
  exit 1
fi

echo "topology scrub: clean (no fleet hostnames, no RFC1918 addresses in tracked files)"
exit 0
