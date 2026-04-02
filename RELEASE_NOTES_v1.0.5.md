# Tile Me v1.0.5

Tile Me v1.0.5 is a focused patch release for the remaining tile-positioning bug on displays whose arranged screen frame is vertically offset.

## Highlights

- fixed Accessibility coordinate conversion for offset displays so `2x2` bottom-row tiles no longer land below the bezel area
- fixed upward moves that could still place a window into the lower half of the screen instead of the true top tile
- kept tile geometry on `visibleFrame` while mapping Accessibility positions from the global top edge used by macOS Accessibility APIs

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
