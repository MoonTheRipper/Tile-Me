# Tile Me

Tile Me is a lightweight native macOS menu bar app for tiling and organizing windows. It uses Swift, SwiftUI, and macOS Accessibility APIs to move the focused window into recursive split-tree layouts across one or more displays.

## Project Overview

Tile Me is built for a menu bar-first workflow:

- assign layouts per display
- move the focused window into a chosen tile
- maximize the focused window
- move windows between displays
- trigger actions from native global shortcuts or the menu bar
- keep settings local, compact, and efficient

The codebase stays split into clear native layers:

- `TileMe/App`: app startup, release experience, menu bar wiring, and workflow coordination
- `TileMe/UI`: menu bar UI, welcome/onboarding UI, preferences UI, and shared SwiftUI components
- `TileMe/Domain`: recursive layout engine, display logic, workspace assignment logic, and shortcut models
- `TileMe/Infrastructure`: Accessibility control, hotkey registration, persistence, and system integrations

## Features In v1.0.3

- native macOS menu bar app with a restrained Settings window
- built-in preset families: `1x2`, `2x1`, and grids from `2x2` through `5x5`
- recursive split-tree layout engine ready for uneven and nested layouts
- per-display layout assignment, copy, and mirror behavior
- focused-window tiling, maximize, and next-display actions
- directional tile traversal and direct tile shortcuts with visible-frame-aligned grid movement
- lightweight GitHub release update checks with browser handoff
- local persistence for layouts, assignments, and shortcuts
- first-run welcome, quick start help, and Accessibility onboarding

## Permissions

Tile Me requires **Accessibility** permission on macOS before it can inspect or move another app's windows.

Without this permission, you can still:

- open the app
- inspect display assignments
- configure layouts
- edit shortcuts

With permission enabled, Tile Me can:

- inspect the focused window
- move or resize supported windows
- apply tile, maximize, and display-move actions from the menu bar or global shortcuts

Enable permission in:

- `System Settings > Privacy & Security > Accessibility`

Tile Me includes direct buttons to request access, open the right System Settings pane, and refresh permission status.

Quick Start can be reopened later from `Help / Quick Start…` in the menu bar or from Settings.
Update checks can be triggered later from the menu bar or Settings.

## Install Tile Me

1. Download the DMG.
2. Open it.
3. Drag Tile Me to Applications.
4. Open Tile Me from Applications.

If macOS blocks the app:

Because this release is not signed and notarized, macOS may warn that Tile Me is from an unidentified developer. If you trust the release source:

1. Try to open Tile Me once.
2. Open `System Settings > Privacy & Security`.
3. Scroll to the Security section.
4. Click `Open Anyway` for Tile Me.
5. Confirm that you want to open it.

Future signed and notarized releases may improve the first-open experience.

## Build From Source

Requirements:

- macOS with Xcode installed
- command-line access to `xcodebuild`

The included scripts automatically use the standard Xcode developer directory when it is available.

Build:

```bash
./Scripts/build.sh
```

Run:

```bash
./Scripts/run.sh
```

This builds the app and opens `Tile Me.app`.

Test:

```bash
./Scripts/test.sh
```

Package a release build:

```bash
./Scripts/package-release.sh
```

## Known Limitations

- v1.0.3 ships built-in layouts only; there is no dynamic freeform tiling editor yet
- nested uneven layouts are supported by the engine, but not yet exposed as user-editable presets in the UI
- dense layouts up to `5x5` are supported, but some macOS app windows may clamp or resist very small tile sizes
- some macOS windows cannot be moved or resized through Accessibility APIs
- fullscreen-style behavior is implemented as visible-frame maximize placement in v1.0.3

## Troubleshooting

- If Accessibility looks enabled in System Settings but Tile Me still reports `trusted=false` when run from Xcode, test the built `Tile Me.app` directly from Finder and approve that exact binary in Accessibility. Xcode-launched builds may require separate approval entries.

## Support

- Open `Support…` from the menu bar or Settings for release help, feedback, and support links.
- Support development on Ko-fi: <https://ko-fi.com/moontheripper>
- Report bugs or send feature requests by email: <mailto:briviamoon@gmail.com>
- Optional GitHub links for advanced users:
  - Project: <https://github.com/moontheripper/Tile-Me>
  - Issues: <https://github.com/moontheripper/Tile-Me/issues>

## Roadmap

- v1.1.0 is planned to introduce dynamic custom and freeform tiling on top of the existing recursive split-tree engine
