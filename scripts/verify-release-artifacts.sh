#!/usr/bin/env bash
set -euo pipefail

# Validate release artifacts produced by the packaging pipeline.
# Checks include bundle metadata, archive contents, checksum entries, and DMG format.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-gPhoto Studio}"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-GPhotoStudio}"
BUNDLE_ID="${BUNDLE_ID:-org.gphoto.gphotostudio}"
VERSION_FILE="${ROOT_DIR}/VERSION"
DEFAULT_VERSION=""
if [[ -f "${VERSION_FILE}" ]]; then
  DEFAULT_VERSION="$(tr -d '[:space:]' < "${VERSION_FILE}")"
fi
VERSION="${VERSION:-${DEFAULT_VERSION}}"
DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist}"
REQUIRE_DMG="${REQUIRE_DMG:-1}"
CHECK_ICON="${CHECK_ICON:-1}"

APP_PATH="${DIST_DIR}/${APP_NAME}.app"
ZIP_PATH="${DIST_DIR}/${APP_NAME}.zip"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"
CHECKSUMS_PATH="${DIST_DIR}/${APP_NAME}-SHA256.txt"
MANIFEST_PATH="${DIST_DIR}/${APP_NAME}-release-manifest.txt"
INFO_PLIST="${APP_PATH}/Contents/Info.plist"

require_file() {
  local path="$1"
  if [[ ! -e "${path}" ]]; then
    echo "Missing required file: ${path}" >&2
    exit 1
  fi
}

plist_value() {
  local key="$1"
  /usr/libexec/PlistBuddy -c "Print :${key}" "${INFO_PLIST}" 2>/dev/null || true
}

echo "Verifying release artifacts in ${DIST_DIR}"

require_file "${APP_PATH}"
require_file "${ZIP_PATH}"
require_file "${CHECKSUMS_PATH}"
require_file "${MANIFEST_PATH}"

if [[ "${REQUIRE_DMG}" == "1" ]]; then
  require_file "${DMG_PATH}"
fi

require_file "${INFO_PLIST}"

actual_display_name="$(plist_value CFBundleDisplayName)"
actual_executable="$(plist_value CFBundleExecutable)"
actual_bundle_id="$(plist_value CFBundleIdentifier)"
actual_short_version="$(plist_value CFBundleShortVersionString)"
actual_bundle_version="$(plist_value CFBundleVersion)"

# Ensure runtime metadata matches expected release naming/version context.
if [[ "${actual_display_name}" != "${APP_NAME}" ]]; then
  echo "CFBundleDisplayName mismatch: expected '${APP_NAME}', got '${actual_display_name}'" >&2
  exit 1
fi

if [[ "${actual_executable}" != "${EXECUTABLE_NAME}" ]]; then
  echo "CFBundleExecutable mismatch: expected '${EXECUTABLE_NAME}', got '${actual_executable}'" >&2
  exit 1
fi

if [[ "${actual_bundle_id}" != "${BUNDLE_ID}" ]]; then
  echo "CFBundleIdentifier mismatch: expected '${BUNDLE_ID}', got '${actual_bundle_id}'" >&2
  exit 1
fi

if [[ -n "${VERSION}" && "${actual_short_version}" != "${VERSION}" ]]; then
  echo "CFBundleShortVersionString mismatch: expected '${VERSION}', got '${actual_short_version}'" >&2
  exit 1
fi

if [[ -n "${VERSION}" && "${actual_bundle_version}" != "${VERSION}" ]]; then
  echo "CFBundleVersion mismatch: expected '${VERSION}', got '${actual_bundle_version}'" >&2
  exit 1
fi

# Confirm the ZIP contains the executable (and icon when enabled).
if ! unzip -l "${ZIP_PATH}" | grep -F "${APP_NAME}.app/Contents/MacOS/${EXECUTABLE_NAME}" >/dev/null; then
  echo "ZIP archive missing executable entry." >&2
  exit 1
fi

if [[ "${CHECK_ICON}" == "1" ]]; then
  icon_file="$(plist_value CFBundleIconFile)"
  if [[ -z "${icon_file}" ]]; then
    echo "CFBundleIconFile is missing." >&2
    exit 1
  fi

  if [[ ! -f "${APP_PATH}/Contents/Resources/${icon_file}" ]]; then
    echo "Icon file not found in app resources: ${icon_file}" >&2
    exit 1
  fi

  if ! unzip -l "${ZIP_PATH}" | grep -F "${APP_NAME}.app/Contents/Resources/${icon_file}" >/dev/null; then
    echo "ZIP archive missing icon file entry." >&2
    exit 1
  fi
fi

# Ensure checksum and manifest files include expected entries.
zip_basename="$(basename "${ZIP_PATH}")"
if ! grep -F "${zip_basename}" "${CHECKSUMS_PATH}" >/dev/null; then
  echo "Checksum file missing ZIP hash entry." >&2
  exit 1
fi

if [[ "${REQUIRE_DMG}" == "1" ]]; then
  dmg_basename="$(basename "${DMG_PATH}")"
  if ! grep -F "${dmg_basename}" "${CHECKSUMS_PATH}" >/dev/null; then
    echo "Checksum file missing DMG hash entry." >&2
    exit 1
  fi

  if ! hdiutil imageinfo "${DMG_PATH}" | grep -F "Format: UDZO" >/dev/null; then
    echo "DMG format check failed (expected UDZO)." >&2
    exit 1
  fi
fi

if ! grep -F "app_name=${APP_NAME}" "${MANIFEST_PATH}" >/dev/null; then
  echo "Manifest missing app_name entry." >&2
  exit 1
fi

if ! grep -F "cfbundle_display_name=${APP_NAME}" "${MANIFEST_PATH}" >/dev/null; then
  echo "Manifest missing cfbundle_display_name entry." >&2
  exit 1
fi

if [[ -n "${VERSION}" ]] && ! grep -F "version=${VERSION}" "${MANIFEST_PATH}" >/dev/null; then
  echo "Manifest missing expected version entry." >&2
  exit 1
fi

echo "Release artifact verification passed."
