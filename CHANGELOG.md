# Changelog

All notable changes to Tile Me are documented in this file.

## [1.0.1] - 2026-03-28

### Added

- lightweight GitHub release update checks with automatic launch checks and a manual `Check for Updates…` action
- restrained native update prompts with `Download Update`, `Remind Me Later`, and `Skip This Version`
- a simple Settings toggle for automatic update checks

### Changed

- updated app and release metadata for `v1.0.1`
- kept update download handoff in the user’s default browser without adding an in-app installer

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
