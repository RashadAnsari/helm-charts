#!/usr/bin/env bash
# Keeps every version reference equal to the VERSION file.
# Usage: version.sh sync   write VERSION into every file
#        version.sh check  fail if any file differs
set -euo pipefail
cd "$(dirname "$0")/.."

version="$(tr -d '[:space:]' < VERSION)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "VERSION must be X.Y.Z, got: $version"; exit 1; }

files=(
  charts/helmet/Chart.yaml
  charts/helmet-app/Chart.yaml
  charts/helmet/README.md
  charts/helmet/examples/README.md
  charts/helmet-app/README.md
  README.md
)

# Rewrites, in order: a Chart.yaml's own version and appVersion; the version line
# under a `- name: helmet` dependency, quoted or not; `helm pull|install
# ... --version`; and the helmet-X.Y.Z release tag in download URLs.
rewrite() {
  V="$version" perl -pe '
    s/^(version|appVersion): ".*"/$1: "$ENV{V}"/ if $ARGV =~ /Chart\.yaml$/;
    $dep = 1 if /^\s*- name: helmet$/;
    $dep = 0 if $dep && s/^(\s+version: "?)[0-9][^"\s]*/$1$ENV{V}/;
    s/(charts\/helmet(?:-app)?\S* --version )[0-9][^\s]*/$1$ENV{V}/g;
    s/\bhelmet-[0-9]+\.[0-9]+\.[0-9]+/helmet-$ENV{V}/g;
  ' "$1"
}

case "${1:-}" in
  sync)
    for f in "${files[@]}"; do rewrite "$f" > "$f.tmp" && cat "$f.tmp" > "$f" && rm "$f.tmp"; done
    echo "Set version $version"
    ;;
  check)
    failed=0
    for f in "${files[@]}"; do
      rewrite "$f" | diff -q - "$f" >/dev/null || { echo "$f is out of sync with VERSION"; failed=1; }
    done
    [ "$failed" = 0 ] || { echo "Run: make version-sync"; exit 1; }
    echo "Every version reference is $version"
    ;;
  *) echo "Usage: $0 sync|check"; exit 1 ;;
esac
