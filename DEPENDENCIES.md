# Dependencies

## Runtime Dependencies

1. macOS 13 or newer
2. `gphoto2` CLI in `PATH`

Install `gphoto2` with Homebrew:

```bash
brew install gphoto2
```

## Build Dependencies

1. Xcode Command Line Tools
2. Swift 5.9+ (or the toolchain bundled with Xcode 15+)
3. `zip` and `hdiutil` (included with macOS) for packaging scripts

Install Command Line Tools:

```bash
xcode-select --install
```

## Optional Dependencies

1. Python 3 + Pillow (only for `scripts/generate-icon-assets.sh`)

Install optional icon-generation dependency:

```bash
python3 -m pip install --upgrade pillow
```
