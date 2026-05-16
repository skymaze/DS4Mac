#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -n "${DS4_DIR:-}" ]]; then
  DS4_SOURCE="$DS4_DIR"
elif [[ -d "$ROOT/Vendor/ds4" ]]; then
  DS4_SOURCE="$ROOT/Vendor/ds4"
elif [[ -d "$ROOT/../ds4" ]]; then
  DS4_SOURCE="$ROOT/../ds4"
else
  echo "Unable to find ds4 source. Set DS4_DIR or add Vendor/ds4." >&2
  exit 1
fi

APP_BUNDLE="${1:-${DS4_APP_BUNDLE:-}}"
if [[ -z "$APP_BUNDLE" && -n "${TARGET_BUILD_DIR:-}" && -n "${WRAPPER_NAME:-}" ]]; then
  APP_BUNDLE="$TARGET_BUILD_DIR/$WRAPPER_NAME"
fi

make -C "$DS4_SOURCE" ds4-server

if [[ -z "$APP_BUNDLE" ]]; then
  echo "Built $DS4_SOURCE/ds4-server"
  echo "Pass an app bundle path, set DS4_APP_BUNDLE, or run from Xcode to embed it."
  exit 0
fi

install -d "$APP_BUNDLE/Contents/MacOS"
install -d "$APP_BUNDLE/Contents/Resources/metal"
install -d "$APP_BUNDLE/Contents/Resources/Licenses"

install -m 755 "$DS4_SOURCE/ds4-server" "$APP_BUNDLE/Contents/MacOS/ds4-server"
cp "$DS4_SOURCE"/metal/*.metal "$APP_BUNDLE/Contents/Resources/metal/"
cp "$DS4_SOURCE/LICENSE" "$APP_BUNDLE/Contents/Resources/Licenses/ds4-LICENSE"
git -C "$DS4_SOURCE" rev-parse HEAD > "$APP_BUNDLE/Contents/Resources/ds4-revision.txt"

echo "Embedded ds4 sidecar into $APP_BUNDLE"
