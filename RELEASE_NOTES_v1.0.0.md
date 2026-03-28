# Tile Me v1.0.0

Tile Me v1.0.0 is the first public release of the native macOS menu bar tiling app.

## Highlights

- native Swift and SwiftUI menu bar app
- recursive split-tree layout engine
- built-in tiling presets for common window arrangements
- per-display layout assignment
- focused-window tiling, maximize, and display movement
- native global shortcuts, including directional traversal
- first-run welcome flow, Quick Start help, and Accessibility onboarding

## Permissions

Tile Me needs Accessibility permission before it can inspect or move other apps' windows. The release includes direct guidance and refresh actions in Settings.

Quick Start can be reopened later from the menu bar, and Support now lives separately from the one-time welcome flow.

## Known Limitations

- v1.0.0 ships built-in layouts only
- some macOS windows may reject small or exact tile sizes
- fullscreen behavior is visible-frame maximize, not native fullscreen takeover

## What’s Next

v1.1.0 is planned to add dynamic custom and freeform tiling on top of the current recursive split-tree foundation.
