# Tile Me v1.0.3

Tile Me v1.0.3 is a focused bug-fix release for keyboard tile movement and grid placement on macOS displays with inset visible areas.

## Highlights

- fixed `2x2` grid placement so top and bottom rows partition the display `visibleFrame` correctly instead of drifting above or below the usable screen area
- fixed arrow-key movement so moving upward from the bottom row lands in the correct top-row tile instead of reusing the wrong row interpretation
- unified direct tile placement and keyboard traversal around the same visible-frame tile geometry and added debug logging for tile movement diagnostics

## Install Tile Me

1. Download the DMG.
2. Open it.
3. Drag Tile Me to Applications.
4. Open Tile Me from Applications.

If macOS blocks the app, try to open it once, then open `System Settings > Privacy & Security` and click `Open Anyway` for Tile Me. Future signed and notarized releases may improve the first-open experience.

## Notes

- update downloads still open in the default browser
- some app windows may clamp very dense layouts instead of matching every tile exactly
- v1.1.0 is still planned for dynamic custom and freeform tiling
