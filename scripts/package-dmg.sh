#!/usr/bin/env bash
set -euo pipefail

# Build a drag-and-drop DMG containing the app bundle and Applications shortcut.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-gPhoto Studio}"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
STAGING_DIR="${DIST_DIR}/dmg-staging"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"

if [[ ! -d "${APP_DIR}" ]]; then
  echo "App bundle not found. Building it first..."
  "${ROOT_DIR}/scripts/build-macos-app.sh"
fi

# Stage files into a temporary folder that becomes the DMG volume content.
rm -rf "${STAGING_DIR}" "${DMG_PATH}"
mkdir -p "${STAGING_DIR}"
cp -R "${APP_DIR}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

# Use UDZO (compressed read-only) for a compact installer image.
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}" || {
    rm -rf "${STAGING_DIR}"
    echo "DMG creation failed in this environment."
    echo "Try running this on a non-sandboxed macOS shell or use scripts/package-zip.sh."
    exit 1
  }

rm -rf "${STAGING_DIR}"

echo "Done: ${DMG_PATH}"
