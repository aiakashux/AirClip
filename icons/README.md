# Airclip icon source of truth

The canonical shared icons live in `icons/svg/` and are registered in `catalog.json`.

1. Add or replace the SVG in `icons/svg/`.
2. Add its Mac and Android targets to `catalog.json`.
3. Run `python3 scripts/sync-icons.py`.
4. Open `icons/icon-library.html` to review every icon visually.

Run `python3 scripts/sync-icons.py --check` in CI or before committing to detect drift.

Platform-native symbols (for example macOS window controls) stay native and are intentionally not duplicated here.
