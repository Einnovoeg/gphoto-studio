# gPhoto Studio

gPhoto Studio is a native macOS desktop application for controlling cameras through `gphoto2`, with workflow ideas inspired by `digiCamControl`.

Current stable version: `1.0.0`

## What It Does

gPhoto Studio provides a macOS GUI for common tethered photography tasks:

- discover and select connected cameras
- capture images directly to the Mac
- preview live frames when the camera supports preview capture
- inspect and change common camera settings
- apply quick presets for ISO, shutter speed, and aperture
- run timelapse sequences
- watch for tethered camera events and auto-download new files

## Why This Project Exists

`gphoto2` is powerful but command-line driven. `digiCamControl` popularized a more accessible desktop workflow, but it is primarily Windows-oriented. gPhoto Studio brings that style of workflow to macOS with a native SwiftUI app while still using `gphoto2` as the device backend.

## Installation

### Option 1: Run From Source

Requirements:

1. macOS 13 or newer
2. Xcode Command Line Tools
3. `gphoto2` installed and available in `PATH`

Install prerequisites:

```bash
xcode-select --install
brew install gphoto2
```

Build:

```bash
swift build
```

Run:

```bash
swift run GPhotoStudio
```

### Option 2: Build a Native `.app`

```bash
./scripts/build-macos-app.sh
```

Output:

- `dist/gPhoto Studio.app`

### Option 3: Build Release Artifacts

```bash
./scripts/build-release-artifacts.sh
```

Outputs:

- `dist/gPhoto Studio.app`
- `dist/gPhoto Studio.zip`
- `dist/gPhoto Studio.dmg`
- `dist/gPhoto Studio-SHA256.txt`
- `dist/gPhoto Studio-release-manifest.txt`

## Release Versioning

- The canonical project version is stored in [`VERSION`](VERSION).
- Releases are tagged as `v<version>`.
- Release notes are tracked in [`CHANGELOG.md`](CHANGELOG.md).
- GitHub releases can be published with [`scripts/publish-github-release.sh`](scripts/publish-github-release.sh).

## Testing and Verification

Run unit tests:

```bash
swift test
```

Verify packaged artifacts:

```bash
./scripts/verify-release-artifacts.sh
```

## Dependencies

Runtime dependencies:

- `gphoto2`

Build dependencies:

- Swift 5.9+
- Xcode Command Line Tools
- `zip` and `hdiutil` for release packaging

Optional dependency:

- Python 3 with Pillow for generated icon assets

Additional detail is documented in [DEPENDENCIES.md](DEPENDENCIES.md).

## License

This repository's original source code is licensed under the [MIT License](LICENSE).

## Third-Party Credits and Compliance

This project depends on and credits the original upstream authors of the software it builds upon:

- `gphoto2` by Marcus Meissner and the gPhoto contributors
- `digiCamControl` by Duka Istvan

Important compliance notes:

- gPhoto Studio does not bundle `gphoto2` source code in the repository.
- gPhoto Studio invokes the separately installed `gphoto2` executable as an external dependency.
- If you redistribute builds that include third-party software, you must also comply with the upstream licenses of those third-party components.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for credit, attribution, and bundled upstream license texts.

## Upstream References

- `gphoto2` GitHub: [https://github.com/gphoto/gphoto2](https://github.com/gphoto/gphoto2)
- `gphoto.org`: [http://www.gphoto.org](http://www.gphoto.org)
- gPhoto SourceForge files: [https://sourceforge.net/projects/gphoto/files/](https://sourceforge.net/projects/gphoto/files/)
- `digiCamControl` SourceForge: [https://sourceforge.net/projects/digicamcontrol/](https://sourceforge.net/projects/digicamcontrol/)

## Support

- Buy Me a Coffee: [buymeacoffee.com/einnovoeg](https://buymeacoffee.com/einnovoeg)
