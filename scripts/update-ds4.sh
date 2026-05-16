#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DS4_SOURCE="${DS4_DIR:-$ROOT/Vendor/ds4}"
TARGET="${1:-origin/main}"
APP_BUNDLE="${2:-${DS4_APP_BUNDLE:-}}"

if [[ ! -d "$DS4_SOURCE/.git" ]]; then
  echo "Expected a ds4 git checkout at $DS4_SOURCE." >&2
  echo "Add it as Vendor/ds4 or set DS4_DIR." >&2
  exit 1
fi

git -C "$DS4_SOURCE" fetch --tags origin
git -C "$DS4_SOURCE" checkout "$TARGET"
"$ROOT/scripts/build-sidecar.sh" "$APP_BUNDLE"

REVISION="$(git -C "$DS4_SOURCE" rev-parse --short HEAD)"
echo "ds4 is ready at $REVISION"
