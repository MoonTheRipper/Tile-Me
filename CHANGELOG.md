# Changelog

All notable changes to Tile Me are documented in this file.

## [1.0.3] - 2026-04-02

### Fixed

- corrected grid tile geometry to resolve from each display's `visibleFrame` so bottom-row windows no longer slip under the bottom bezel and top-row windows no longer sit too high
- aligned keyboard arrow traversal with the same top-origin row ordering used for tile placement, fixing `2x2` upward moves that could reuse the wrong tile index

### Changed

- unified direct tile selection and keyboard traversal around one logical row and column to `CGRect` helper with final target-frame clamping
- added debug-only logging for display IDs, visible frames, source and destination tile indices, logical row and column, and computed target frames
- updated app and release metadata for `v1.0.3`

## [1.0.2] - 2026-03-28

### Added

- built-in preset coverage for `1x2`, `2x1`, and every grid from `2x2` through `5x5`
- compact grouped layout menus for preset selection in both the menu bar and Settings

### Changed

- updated app and release metadata for `v1.0.2`
- kept dense-layout window moves on the existing constrained-fit reporting path instead of treating app-side clamping as an engine failure

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
