#!/usr/bin/env bash
set -euo pipefail

# Sign with Developer ID, submit to Apple notarization, and optionally staple.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-gPhoto Studio}"
DIST_DIR="${ROOT_DIR}/dist"
APP_PATH="${APP_PATH:-${DIST_DIR}/${APP_NAME}.app}"
ZIP_PATH="${ZIP_PATH:-${DIST_DIR}/${APP_NAME}-notarize.zip}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-}"
STAPLE="${STAPLE:-1}"
BUILD_IF_MISSING="${BUILD_IF_MISSING:-1}"

if [[ -z "${SIGN_IDENTITY}" ]]; then
  echo "Missing SIGN_IDENTITY."
  echo "Example: SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'"
  exit 1
fi

if [[ -z "${KEYCHAIN_PROFILE}" ]]; then
  echo "Missing KEYCHAIN_PROFILE for notarytool."
  echo "Create it with: xcrun notarytool store-credentials <profile-name> ..."
  exit 1
fi

if [[ ! -d "${APP_PATH}" ]]; then
  if [[ "${BUILD_IF_MISSING}" == "1" ]]; then
    echo "App bundle missing; building first..."
    "${ROOT_DIR}/scripts/build-macos-app.sh"
  else
    echo "App bundle not found: ${APP_PATH}"
    exit 1
  fi
fi

# Sign with hardened runtime and timestamp for notarization compliance.
echo "Signing app: ${APP_PATH}"
codesign --force --deep --options runtime --timestamp --sign "${SIGN_IDENTITY}" "${APP_PATH}"

echo "Verifying signature"
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

# Notary submission requires a ZIP payload.
echo "Creating notarization archive: ${ZIP_PATH}"
rm -f "${ZIP_PATH}"
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

# Wait for notarization result; fail fast on rejection.
echo "Submitting for notarization"
xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${KEYCHAIN_PROFILE}" --wait

if [[ "${STAPLE}" == "1" ]]; then
  # Stapling embeds the notarization ticket so offline systems can validate it.
  echo "Stapling ticket"
  xcrun stapler staple "${APP_PATH}"
  xcrun stapler validate "${APP_PATH}"
fi

echo "Done. Signed and notarized app: ${APP_PATH}"
