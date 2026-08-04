#!/usr/bin/env bash
# Unit suite for check-topology-scrub.sh (#527).
#
# Positive control: a fixture tree that plants a banned hostname MUST fail the
# gate. Without that, a green run could be a dead path. Negative control: the
# real repo at HEAD is clean (the June scrub + #528).
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
script="${repo_root}/.github/scripts/check-topology-scrub.sh"

pass_count=0
fail_count=0
ok()  { printf "  ok    %s\n" "$1"; pass_count=$((pass_count + 1)); }
bad() { printf "  FAIL  %s\n" "$1"; fail_count=$((fail_count + 1)); }

echo "check-topology-scrub suite"

# --- real tree is clean ---
if out="$(bash "$script" 2>&1)"; then
  ok "repo HEAD is clean"
else
  bad "repo HEAD is clean (gate failed on current tree): $out"
fi

work="$(mktemp -d)"
cleanup() { rm -rf "$work"; }
trap cleanup EXIT

# --- positive control: fleet hostname ---
mkdir -p "$work/host/docs"
printf 'Measured on dischord, 2026-07-26:\n' >"$work/host/docs/note.md"
if TOPOLOGY_SCRUB_ROOT="$work/host" bash "$script" >/dev/null 2>&1; then
  bad "detects fleet hostname (expected fail, got pass)"
else
  ok "detects fleet hostname"
fi

# --- positive control: RFC1918 ---
mkdir -p "$work/rfc/docs"
printf 'door at 10.1.1.2:993\n' >"$work/rfc/docs/note.md"
if TOPOLOGY_SCRUB_ROOT="$work/rfc" bash "$script" >/dev/null 2>&1; then
  bad "detects RFC1918 address (expected fail, got pass)"
else
  ok "detects RFC1918 address"
fi

# --- negative control: loopback + RFC5737 doc range are fine ---
mkdir -p "$work/ok/docs"
printf 'listen 127.0.0.1:2525 and example 192.0.2.1:993\n' >"$work/ok/docs/note.md"
if TOPOLOGY_SCRUB_ROOT="$work/ok" bash "$script" >/dev/null 2>&1; then
  ok "allows loopback and RFC5737 documentation ranges"
else
  bad "allows loopback and RFC5737 documentation ranges"
fi

# --- negative control: public repo / domain names are not host tokens ---
mkdir -p "$work/pub/docs"
printf 'see fleet-chezmoi and postern.example.com / skyphusion.org\n' >"$work/pub/docs/note.md"
if TOPOLOGY_SCRUB_ROOT="$work/pub" bash "$script" >/dev/null 2>&1; then
  ok "allows public repo and domain names"
else
  bad "allows public repo and domain names"
fi

echo
echo "${pass_count} passed, ${fail_count} failed"
if [[ "$fail_count" -ne 0 ]]; then
  exit 1
fi
exit 0
