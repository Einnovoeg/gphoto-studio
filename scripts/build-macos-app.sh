#!/usr/bin/env bash
set -euo pipefail

# Build a native `.app` bundle from the Swift executable target.
# This script supports both ad-hoc signing (default) and Developer ID signing.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-gPhoto Studio}"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-GPhotoStudio}"
BUNDLE_ID="${BUNDLE_ID:-org.gphoto.gphotostudio}"
VERSION="${VERSION:-0.1.0}"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
ADHOC_SIGN="${ADHOC_SIGN:-1}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
ICON_SOURCE="${ICON_SOURCE:-${ROOT_DIR}/resources/gphoto-studio.icns}"
ICON_FILE_NAME="${ICON_FILE_NAME:-gphoto-studio.icns}"

DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
INFO_PLIST="${CONTENTS_DIR}/Info.plist"

if [[ "${BUILD_CONFIG}" != "debug" && "${BUILD_CONFIG}" != "release" ]]; then
  echo "BUILD_CONFIG must be 'debug' or 'release'"
  exit 1
fi

echo "Building ${APP_NAME} (${BUILD_CONFIG})..."
BIN_PATH=""
# Try common SwiftPM build output locations first to avoid unnecessary rebuilds.
CANDIDATE_PATHS=(
  "${ROOT_DIR}/.build/${BUILD_CONFIG}/${EXECUTABLE_NAME}"
  "${ROOT_DIR}/.build/arm64-apple-macosx/${BUILD_CONFIG}/${EXECUTABLE_NAME}"
  "${ROOT_DIR}/.build/x86_64-apple-macosx/${BUILD_CONFIG}/${EXECUTABLE_NAME}"
)

for candidate in "${CANDIDATE_PATHS[@]}"; do
  if [[ -x "${candidate}" ]]; then
    BIN_PATH="${candidate}"
    break
  fi
done

if [[ -z "${BIN_PATH}" ]]; then
  # Build when no prebuilt executable is found in the expected locations.
  echo "No prebuilt binary found. Running swift build..."
  cd "${ROOT_DIR}"
  swift build -c "${BUILD_CONFIG}"
  BIN_DIR="$(swift build -c "${BUILD_CONFIG}" --show-bin-path)"
  BIN_PATH="${BIN_DIR}/${EXECUTABLE_NAME}"
fi

if [[ ! -x "${BIN_PATH}" ]]; then
  echo "Could not locate built binary: ${BIN_PATH}"
  exit 1
fi

# Assemble the macOS bundle folder structure.
echo "Creating app bundle at ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
cp "${BIN_PATH}" "${MACOS_DIR}/${EXECUTABLE_NAME}"
chmod +x "${MACOS_DIR}/${EXECUTABLE_NAME}"

# Add icon metadata only when an icon source file is present.
ICON_PLIST_SNIPPET=""
if [[ -f "${ICON_SOURCE}" ]]; then
  cp "${ICON_SOURCE}" "${RESOURCES_DIR}/${ICON_FILE_NAME}"
  ICON_PLIST_SNIPPET=$'  <key>CFBundleIconFile</key>\n  <string>'"${ICON_FILE_NAME}"$'</string>'
fi

# Generate a minimal Info.plist suitable for local builds and CI packaging.
cat > "${INFO_PLIST}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${EXECUTABLE_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
${ICON_PLIST_SNIPPET}
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.photography</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

# Classic Finder marker file for app bundles.
echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# Apply requested signing mode.
if [[ -n "${SIGN_IDENTITY}" ]]; then
  echo "Signing with identity: ${SIGN_IDENTITY}"
  codesign --force --deep --sign "${SIGN_IDENTITY}" "${APP_DIR}"
elif [[ "${ADHOC_SIGN}" == "1" ]]; then
  echo "Applying ad-hoc signature"
  codesign --force --deep --sign - "${APP_DIR}"
fi

echo "Done: ${APP_DIR}"
