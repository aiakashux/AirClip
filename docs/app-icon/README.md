# AirClip App Icon

Put the final main app icon export here:

```text
docs/app-icon/AirClipAppIcon.png
```

Preferred source:

- 1024x1024 px PNG, sRGB
- Square canvas
- No rounded-corner mask baked into the image
- No menu bar template icon treatment
- Avoid heavy baked shadows, bevels, or glass effects

For macOS 26/iOS 26, keep the source artwork simple and let the system or Icon
Composer apply platform treatments. If the Figma icon is layered, keep a layered
source export separately and use this PNG as the generated fallback.

Current Figma source:

```text
https://www.figma.com/design/p6I5nXWy6uzKwQcwwdu8xp/AirClip?node-id=231-6092
```

This file requires a signed-in Figma session before it can be exported from this
workspace.

After adding the source image, run:

```sh
./scripts/generate-app-icons.sh
```

That will generate the macOS, iOS, and Android launcher icon assets currently
available in this repo.
