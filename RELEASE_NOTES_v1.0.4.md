# Tile Me v1.0.4

Tile Me v1.0.4 is a focused patch release for the remaining display-coordinate bug affecting tile placement on screens with inset usable areas.

## Highlights

- fixed the remaining frame-conversion bug that could place bottom-row tiles below the visible display area on some displays
- fixed upward moves that could land in the wrong half of the screen because Accessibility coordinate reflection was using the wrong display bounds
- kept tile geometry on `visibleFrame` while restoring Accessibility/AppKit coordinate conversion to the full display frame

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
