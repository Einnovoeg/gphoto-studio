#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-gPhoto Studio}"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-GPhotoStudio}"
BUNDLE_ID="${BUNDLE_ID:-org.gphoto.gphotostudio}"
VERSION="${VERSION:-0.1.0}"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
GENERATE_ICON="${GENERATE_ICON:-1}"
BUILD_DMG="${BUILD_DMG:-1}"
RUN_VERIFY="${RUN_VERIFY:-1}"

DIST_DIR="${ROOT_DIR}/dist"
APP_PATH="${DIST_DIR}/${APP_NAME}.app"
ZIP_PATH="${DIST_DIR}/${APP_NAME}.zip"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"
CHECKSUMS_PATH="${DIST_DIR}/${APP_NAME}-SHA256.txt"
MANIFEST_PATH="${DIST_DIR}/${APP_NAME}-release-manifest.txt"

mkdir -p "${DIST_DIR}"

if [[ "${GENERATE_ICON}" == "1" ]]; then
  echo "[1/6] Generating icon assets"
  "${ROOT_DIR}/scripts/generate-icon-assets.sh"
fi

echo "[2/6] Building app bundle"
APP_NAME="${APP_NAME}" \
EXECUTABLE_NAME="${EXECUTABLE_NAME}" \
BUNDLE_ID="${BUNDLE_ID}" \
VERSION="${VERSION}" \
BUILD_CONFIG="${BUILD_CONFIG}" \
"${ROOT_DIR}/scripts/build-macos-app.sh"

echo "[3/6] Packaging ZIP"
APP_NAME="${APP_NAME}" "${ROOT_DIR}/scripts/package-zip.sh"

if [[ "${BUILD_DMG}" == "1" ]]; then
  echo "[4/6] Packaging DMG"
  APP_NAME="${APP_NAME}" "${ROOT_DIR}/scripts/package-dmg.sh"
else
  echo "[4/6] Skipping DMG (BUILD_DMG=${BUILD_DMG})"
fi

echo "[5/6] Writing checksums and manifest"
rm -f "${CHECKSUMS_PATH}" "${MANIFEST_PATH}"

(
  cd "${DIST_DIR}"
  if [[ -f "${APP_NAME}.zip" ]]; then
    shasum -a 256 "${APP_NAME}.zip" >> "${CHECKSUMS_PATH}"
  fi
  if [[ -f "${APP_NAME}.dmg" ]]; then
    shasum -a 256 "${APP_NAME}.dmg" >> "${CHECKSUMS_PATH}"
  fi
)

plist_value() {
  local key="$1"
  /usr/libexec/PlistBuddy -c "Print :${key}" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || true
}

{
  echo "app_name=${APP_NAME}"
  echo "executable_name=${EXECUTABLE_NAME}"
  echo "bundle_id=${BUNDLE_ID}"
  echo "version=${VERSION}"
  echo "build_config=${BUILD_CONFIG}"
  echo "generated_at_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "cfbundle_identifier=$(plist_value CFBundleIdentifier)"
  echo "cfbundle_short_version=$(plist_value CFBundleShortVersionString)"
  echo "cfbundle_version=$(plist_value CFBundleVersion)"
  echo "cfbundle_display_name=$(plist_value CFBundleDisplayName)"
  if [[ -f "${ZIP_PATH}" ]]; then
    echo "zip_bytes=$(stat -f %z "${ZIP_PATH}")"
  fi
  if [[ -f "${DMG_PATH}" ]]; then
    echo "dmg_bytes=$(stat -f %z "${DMG_PATH}")"
  fi
} > "${MANIFEST_PATH}"

if [[ "${RUN_VERIFY}" == "1" ]]; then
  echo "[6/6] Verifying artifacts"
  APP_NAME="${APP_NAME}" \
  EXECUTABLE_NAME="${EXECUTABLE_NAME}" \
  BUNDLE_ID="${BUNDLE_ID}" \
  REQUIRE_DMG="${BUILD_DMG}" \
  "${ROOT_DIR}/scripts/verify-release-artifacts.sh"
else
  echo "[6/6] Skipping verification (RUN_VERIFY=${RUN_VERIFY})"
fi

echo "Done."
echo "- App: ${APP_PATH}"
echo "- ZIP: ${ZIP_PATH}"
if [[ -f "${DMG_PATH}" ]]; then
  echo "- DMG: ${DMG_PATH}"
fi
echo "- Checksums: ${CHECKSUMS_PATH}"
echo "- Manifest: ${MANIFEST_PATH}"
