# Changelog

All notable changes to this project will be documented in this file.

This project follows [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-03-13

### Added

- Native macOS app for camera discovery, capture, live preview, presets, timelapse, and tethered download workflows
- Release packaging for `.app`, `.zip`, `.dmg`, checksums, and a release manifest
- GitHub Actions release build workflow
- Dependency documentation, third-party notices, and bundled upstream license texts
- Buy Me a Coffee support link in the app and repository docs
- Unit tests covering key `gphoto2` output parsers

### Changed

- Polished the SwiftUI interface with a dashboard strip, clearer section headers, native command menu actions, and queue controls
- Improved release script comments, resilience, and version metadata handling
- Expanded README installation and compliance documentation

### Fixed

- Sanitized git history author metadata to remove unintended local personal identity leakage
- Hardened parser behavior for empty auto-detect tables and config parsing edge cases
- Added fallback handling for environments where `iconutil` intermittently rejects otherwise valid iconsets
