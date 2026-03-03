# gPhoto Studio

Native macOS desktop GUI for [gphoto2](https://github.com/gphoto/gphoto2), with workflow patterns inspired by [digiCamControl](https://sourceforge.net/projects/digicamcontrol/).

## What This Software Does

gPhoto Studio provides a native SwiftUI interface for common tethered-photography tasks on macOS:

- camera discovery and selection
- one-click capture and download
- live preview polling
- quick camera setting control (ISO, shutter, aperture, and more)
- preset-driven capture
- timelapse capture queues
- tethered event watch with auto-download

## Project References

- gphoto2 GitHub: [https://github.com/gphoto/gphoto2](https://github.com/gphoto/gphoto2)
- gphoto.org: [http://www.gphoto.org](http://www.gphoto.org)
- gPhoto SourceForge files: [https://sourceforge.net/projects/gphoto/files/](https://sourceforge.net/projects/gphoto/files/)
- digiCamControl SourceForge: [https://sourceforge.net/projects/digicamcontrol/](https://sourceforge.net/projects/digicamcontrol/)

## Install Requirements

1. macOS 13 or newer
2. Xcode Command Line Tools
3. `gphoto2` installed and available in `PATH`

Install tooling:

```bash
xcode-select --install
brew install gphoto2
```

For full dependency details, see [DEPENDENCIES.md](DEPENDENCIES.md).

## Build and Run

Build:

```bash
swift build
```

Run:

```bash
swift run GPhotoStudio
```

## Testing

Run unit tests:

```bash
swift test
```

## Build a macOS `.app`

```bash
./scripts/build-macos-app.sh
```

Output:

- `dist/gPhoto Studio.app`

## Build Release Artifacts (`.app`, `.zip`, `.dmg`, checksums)

```bash
./scripts/build-release-artifacts.sh
```

Outputs:

- `dist/gPhoto Studio.app`
- `dist/gPhoto Studio.zip`
- `dist/gPhoto Studio.dmg`
- `dist/gPhoto Studio-SHA256.txt`
- `dist/gPhoto Studio-release-manifest.txt`

## Verify Existing Artifacts

```bash
./scripts/verify-release-artifacts.sh
```

## License and Credits

- Project license: [MIT](LICENSE)
- Third-party credits and obligations: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)

Important:

- gPhoto Studio invokes `gphoto2`, which is licensed separately by its upstream authors.
- If you redistribute packages that include third-party tools, ensure you also satisfy those tools' license requirements.

## Support

- Buy Me a Coffee: [buymeacoffee.com/einnovoeg](https://buymeacoffee.com/einnovoeg)
