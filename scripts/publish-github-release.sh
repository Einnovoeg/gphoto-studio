#!/usr/bin/env bash
set -euo pipefail

# Build release artifacts, create the version tag, and publish a GitHub release.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="${ROOT_DIR}/VERSION"
CHANGELOG_FILE="${ROOT_DIR}/CHANGELOG.md"

if [[ ! -f "${VERSION_FILE}" ]]; then
  echo "Missing VERSION file." >&2
  exit 1
fi

VERSION="$(tr -d '[:space:]' < "${VERSION_FILE}")"
TAG="v${VERSION}"
TITLE="gPhoto Studio ${TAG}"
NOTES_FILE="$(mktemp)"

cleanup() {
  rm -f "${NOTES_FILE}"
}
trap cleanup EXIT

extract_release_notes() {
  awk -v version="${VERSION}" '
    $0 ~ "^## \\[" version "\\]" { printing=1; next }
    printing && $0 ~ "^## \\[" { exit }
    printing { print }
  ' "${CHANGELOG_FILE}" | sed '/^[[:space:]]*$/N;/^\n$/D'
}

if [[ ! -f "${CHANGELOG_FILE}" ]]; then
  echo "Missing CHANGELOG.md." >&2
  exit 1
fi

extract_release_notes > "${NOTES_FILE}"
if [[ ! -s "${NOTES_FILE}" ]]; then
  cp "${CHANGELOG_FILE}" "${NOTES_FILE}"
fi

"${ROOT_DIR}/scripts/build-release-artifacts.sh"

if ! git rev-parse "${TAG}" >/dev/null 2>&1; then
  git tag -a "${TAG}" -m "Release ${TAG}"
fi

git push origin "${TAG}"

APP_PATH="${ROOT_DIR}/dist/gPhoto Studio.app"
ZIP_PATH="${ROOT_DIR}/dist/gPhoto Studio.zip"
DMG_PATH="${ROOT_DIR}/dist/gPhoto Studio.dmg"
CHECKSUMS_PATH="${ROOT_DIR}/dist/gPhoto Studio-SHA256.txt"
MANIFEST_PATH="${ROOT_DIR}/dist/gPhoto Studio-release-manifest.txt"

if gh release view "${TAG}" >/dev/null 2>&1; then
  gh release upload "${TAG}" "${ZIP_PATH}" "${DMG_PATH}" "${CHECKSUMS_PATH}" "${MANIFEST_PATH}" --clobber
else
  gh release create "${TAG}" --title "${TITLE}" --notes-file "${NOTES_FILE}"
  # GitHub's uploads endpoint can lag slightly behind release creation.
  sleep 2
  gh release upload "${TAG}" "${ZIP_PATH}" "${DMG_PATH}" "${CHECKSUMS_PATH}" "${MANIFEST_PATH}"
fi
