# Changelog

All notable changes to Tile Me are documented in this file.

## [1.0.0] - 2026-03-28

### Added

- native macOS menu bar app with a Settings window
- recursive split-tree tiling engine with built-in `Halves`, `2x2`, `3x3`, and `4x4` layouts
- focused-window tiling, maximize, and next-display actions through Accessibility APIs
- per-display layout assignment, copy, and mirror behavior
- global shortcut support for direct tile moves and directional traversal
- first-run welcome and quick start flow with a separate support surface

### Changed

- branded the app as `Tile Me`
- added a proper macOS application icon set
- fixed vertical directional traversal behavior for release
- kept developer diagnostics available only in debug builds

### Notes

- dynamic freeform tiling is planned for v1.1.0
