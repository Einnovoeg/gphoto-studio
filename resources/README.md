# App Branding Assets

Optional app icon for bundle builds:

- Place an `.icns` file at `resources/gphoto-studio.icns`
- Or pass `ICON_SOURCE` and `ICON_FILE_NAME` to `scripts/build-macos-app.sh`

To generate a default icon set for this project:

```bash
./scripts/generate-icon-assets.sh
```

Example:

```bash
ICON_SOURCE="/absolute/path/MyIcon.icns" \
ICON_FILE_NAME="MyIcon.icns" \
./scripts/build-macos-app.sh
```
