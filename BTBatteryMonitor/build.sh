#!/usr/bin/env bash
# BT Battery Monitor — local build script (Xcode-less, CLT only)
# Usage: cd BTBatteryMonitor && bash build.sh
# Output: BTBatteryMonitor.app (ad-hoc signed, local testing only)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="BTBatteryMonitor"
APP_BUNDLE="${APP_NAME}.app"
PLIST_SRC="Sources/${APP_NAME}/Resources/Info.plist"
ENTITLEMENTS_SRC="Sources/${APP_NAME}/Resources/${APP_NAME}.entitlements"

echo "==> Building ${APP_NAME} (release)..."
swift build -c release

echo "==> Creating .app bundle structure..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "==> Copying binary..."
cp ".build/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

echo "==> Copying Info.plist..."
cp "${PLIST_SRC}" "${APP_BUNDLE}/Contents/Info.plist"

echo "==> Signing with ad-hoc identity..."
codesign --sign - \
  --entitlements "${ENTITLEMENTS_SRC}" \
  --options runtime \
  --force \
  "${APP_BUNDLE}"

echo ""
echo "Build complete: ${SCRIPT_DIR}/${APP_BUNDLE}"
echo "Run with: open ${APP_BUNDLE}"
echo ""
echo "To launch in background (launchd-safe):"
echo "  open ${APP_BUNDLE}"
