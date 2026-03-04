#!/usr/bin/env bash
set -euo pipefail

# Package the built `.app` bundle into a ZIP archive for distribution.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-gPhoto Studio}"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
ZIP_PATH="${DIST_DIR}/${APP_NAME}.zip"

if [[ ! -d "${APP_DIR}" ]]; then
  echo "App bundle not found. Building it first..."
  "${ROOT_DIR}/scripts/build-macos-app.sh"
fi

# `COPYFILE_DISABLE=1` avoids macOS metadata sidecar files in the archive.
rm -f "${ZIP_PATH}"
(
  cd "${DIST_DIR}"
  COPYFILE_DISABLE=1 zip -qry "${APP_NAME}.zip" "${APP_NAME}.app"
)

echo "Done: ${ZIP_PATH}"
