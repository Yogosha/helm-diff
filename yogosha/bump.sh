#!/usr/bin/env bash
# Bump every Go dependency of a helm-diff source tree to its latest version.
#
# Usage: bump.sh <helm-diff source dir> <overrides file>
#
# - Modules listed in HOLD stay at the version upstream requires (they move in
#   lockstep with k8s.io/* and break the build when bumped on their own).
# - The overrides file lists "<module> <minimum version>" lines, used when a
#   CVE fix only exists as an untagged commit: the module is raised to that
#   version, never lowered.
set -euo pipefail

src="$1"
overrides="$(realpath "$2")"
cd "$src"

HOLD=(
  k8s.io/kube-openapi
)

# semver_gt A B: succeeds when A > B (Go module versions, incl. pseudo-versions).
semver_gt() {
  local a="${1#v}" b="${2#v}"
  local a_core="${a%%-*}" b_core="${b%%-*}"
  local a_pre="" b_pre=""
  [[ "$a" == *-* ]] && a_pre="${a#*-}"
  [[ "$b" == *-* ]] && b_pre="${b#*-}"
  if [[ "$a_core" != "$b_core" ]]; then
    [[ "$(printf '%s\n%s\n' "$a_core" "$b_core" | sort -V | tail -1)" == "$a_core" ]]
    return
  fi
  # same core: a release is greater than any of its pre-releases
  [[ -z "$a_pre" && -n "$b_pre" ]] && return 0
  [[ -n "$a_pre" && -z "$b_pre" ]] && return 1
  # pseudo-versions on the same base sort by timestamp, lexicographically
  [[ "$a_pre" > "$b_pre" ]]
}

declare -A held
for m in "${HOLD[@]}"; do
  held[$m]="$(go list -m -f '{{.Version}}' "$m")"
done

# Build with the running (latest stable) toolchain: raises the go directive so
# that deps requiring a newer Go can be upgraded, and clears the stdlib CVEs.
go get "go@$(go env GOVERSION | sed 's/^go//')" toolchain@none

go get -u ./...

for m in "${HOLD[@]}"; do
  go get "$m@${held[$m]}"
done

while read -r mod ver _; do
  [[ -z "${mod:-}" || "$mod" == \#* ]] && continue
  cur="$(go list -m -f '{{.Version}}' "$mod" 2>/dev/null || true)"
  if [[ -z "$cur" ]]; then
    echo "override $mod: module not used anymore, skipping"
    continue
  fi
  if semver_gt "$ver" "$cur"; then
    echo "override $mod: $cur -> $ver"
    go get "$mod@$ver"
  else
    echo "override $mod: $cur already >= $ver, nothing to do"
  fi
done < "$overrides"

go mod tidy
