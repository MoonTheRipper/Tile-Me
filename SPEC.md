# TileMe Specification

## 1. Product Goal

TileMe is a lightweight native macOS menu bar app built with Swift, SwiftUI, and an Xcode project. It manages external application windows using macOS Accessibility APIs and places them into user-defined tile layouts across one or more displays.

The product goal for v1 is:

- launch as a menu bar app
- expose a restrained native preferences window
- detect connected displays
- model layouts as recursive split trees from the start
- resolve layouts into absolute tile frames for each display
- move the focused window into a chosen tile
- maximize or fullscreen a focused window
- move a focused window to another display
- persist layouts, display assignments, and shortcuts locally
- handle missing permissions cleanly

## 2. Product Constraints

- Native macOS only
- Swift and SwiftUI only
- Xcode project structure
- `xcodebuild`-based build loop
- minimal dependencies, preferably none beyond Apple frameworks
- menu bar first workflow
- low idle overhead
- no grid-only layout model

## 3. App Surfaces

### 3.1 Menu Bar App

Primary surface for fast actions.

- menu bar icon
- quick layout selection
- quick tile actions
- quick display actions
- permission status
- open settings

### 3.2 Preferences Window

Secondary surface for configuration.

- Displays
- Layouts
- Shortcuts
- Permissions
- Advanced later

### 3.3 Onboarding

Lightweight, permission-focused guidance.

- explain Accessibility requirement
- detect trust state
- link user to the correct System Settings location

## 4. Architecture

The app is split into four layers.

### 4.1 App Layer

- `TileMeApp.swift`
- startup wiring
- menu bar scene
- settings scene
- shared app state container

### 4.2 UI Layer

- menu bar UI
- preferences UI
- onboarding UI
- shortcut editor UI
- display assignment UI
- layout editor later

### 4.3 Domain Layer

- layout engine
- display profile logic
- workspace/display assignment logic
- shortcut action model
- tile resolution
- domain models

### 4.4 Infrastructure Layer

- accessibility window control
- focused window lookup
- permission checks
- persistence
- global hotkey registration
- display enumeration

## 5. Target Folder Structure

```text
TileMe/
├── TileMe.xcodeproj
├── TileMe/
│   ├── App/
│   ├── UI/
│   │   ├── MenuBar/
│   │   ├── Preferences/
│   │   ├── Onboarding/
│   │   └── Components/
│   ├── Domain/
│   │   ├── Models/
│   │   ├── LayoutEngine/
│   │   ├── DisplayEngine/
│   │   ├── ShortcutEngine/
│   │   └── WorkspaceEngine/
│   ├── Infrastructure/
│   │   ├── Accessibility/
│   │   ├── Persistence/
│   │   ├── Hotkeys/
│   │   └── System/
│   └── Resources/
├── TileMeTests/
├── Scripts/
├── README.md
├── SPEC.md
└── TASKS.md
```

## 6. Core Data Models

### 6.1 `DisplayProfile`

Represents a connected display and its placement context.

- stable identifier
- user-facing name
- full frame
- visible / usable frame
- scale factor
- built-in / external flag

### 6.2 `LayoutDefinition`

Top-level reusable layout object.

- stable identifier
- name
- root `TileNode`
- metadata needed later for editing

### 6.3 `TileNode`

Recursive split-tree node.

Each node is one of:

- leaf tile
- horizontal split with children
- vertical split with children

Each node must support:

- stable identifier
- child ratios / proportional weights
- future editing metadata

### 6.4 `TileFrame`

Resolved tile output for a specific display.

- stable tile identifier
- display-relative absolute frame
- tile index / ordering metadata for shortcuts and menu rendering

### 6.5 `ShortcutAction`

Structured action model, not hardcoded commands.

Examples:

- move focused window to tile
- maximize / fullscreen placement
- next display
- previous display later
- same tile on another display via additional modifier pattern

### 6.6 `ShortcutBinding`

Persistent keyboard binding description.

- key code
- modifier flags
- optional extra display modifier logic

### 6.7 `WorkspaceProfile`

Persisted workspace/display relationship model.

- per-display layout assignment
- copied layout source
- mirrored profile mode
- per-display preferences

### 6.8 `AppPreferences`

Reserved for lightweight local UI state as the app expands.

V1 keeps persisted state focused on workspace/display assignments and shortcut bindings, with room to extend this model later for onboarding and UI defaults.

## 7. Tiling Engine Design

### 7.1 Core Rule

Layouts are never grid-only. Grids are helper-generated recursive split trees.

### 7.2 Tree Model

The root node defines the full tiling space for a display’s visible frame.

- leaf node: a tile target
- vertical split: divides width among child nodes
- horizontal split: divides height among child nodes

Children are sized by ratios or proportional weights. Resolution must preserve the tree structure while converting to display-specific absolute frames.

### 7.3 Resolution Behavior

The layout engine must:

- accept a `LayoutDefinition`
- accept a display visible frame
- walk the tree recursively
- compute child rectangles proportionally
- emit stable `TileFrame` values in deterministic order

### 7.4 Required Helper Layouts

These are helpers that generate recursive trees, not separate layout systems.

- left/right halves
- `2x2`
- `3x3`
- `4x4`
- helper-ready for `8x8`
- nested uneven samples such as:
  - two top tiles + one bottom wide tile
  - one large left tile + stacked right tiles

### 7.5 Future Readiness

The same model must later support:

- arbitrary nested layouts
- copied templates
- GUI editing
- drag-based editing
- unlimited practical depth

## 8. Display Handling Design

### 8.1 Discovery

- use `NSScreen`
- capture connected displays
- read visible frame and full frame
- update only when screen configuration changes

### 8.2 Assignment Modes

Each display can use:

- its own layout
- a copied layout from another display
- a mirrored display profile

V1 should implement own layout + copied layout cleanly. Mirrored profile can be modeled in persistence even if UI exposure remains minimal in early phases.

Current v1 behavior:

- own layout assignment is supported
- copied layout assignment is supported
- mirrored display assignment is supported in Settings
- the menu bar keeps mirrored controls out to avoid bloating quick actions

### 8.3 Display Navigation

The display engine must support:

- next display
- previous display later if useful
- corresponding-tile placement on another display

## 9. Shortcut Design

### 9.1 Principles

- globally configurable
- persisted locally
- structured action map
- minimal idle overhead

### 9.2 Required Actions

- move focused window to tile `N`
- maximize / fullscreen-style placement
- move focused window to next display
- tile action on another display using an additional modifier concept

### 9.3 Combined Modifier Pattern

Concept:

- base shortcut: apply tile on current display
- additional modifier: same tile action, but target another display

Implementation detail can vary, but the domain model must support this cleanly from the beginning.

## 10. Permission Model

The app requires macOS Accessibility permission to control external windows.

Behavior rules:

- detect trust state at launch and on demand
- never crash if permission is missing
- explain why the permission is required
- offer a direct path to System Settings
- keep the rest of the app functional enough to configure layouts and shortcuts even without permission

## 11. Window Control Design

Window control is backed by protocols for testability.

Required capabilities:

- detect frontmost app
- detect focused window
- inspect current window frame
- set position
- set size
- apply maximize / fullscreen-style placement using the display visible frame in v1
- gracefully reject unsupported windows

## 12. Persistence Model

Persist locally using native APIs only.

Store:

- display-to-layout assignments
- copy / mirror settings
- shortcut bindings

Built-in layout definitions ship in code for v1; user-edited custom layouts are not persisted yet.

Preferred approach:

- `Codable`
- `UserDefaults` or app support JSON store
- simple versioned payloads

## 13. Performance Model

- no aggressive polling
- react to notifications and explicit actions
- register only active hotkeys
- keep launch path short
- keep menu bar UI lightweight
- do window queries only when needed

## 14. Build and Validation Model

- native Xcode project
- `Scripts/build.sh`
- `Scripts/run.sh`
- `Scripts/test.sh`
- `xcodebuild` for build loop
- narrow validation after each phase

## 15. Testing Scope

At minimum:

- layout tree resolution into tile frames
- equal-grid helper generation
- nested split resolution
- stable identifier preservation
- display/profile assignment logic where practical

## 16. Phased Roadmap

### Phase 0

- planning only
- `SPEC.md`
- `TASKS.md`

### Phase 1

- project scaffold
- folder layout
- app shell
- menu bar shell
- preferences shell
- scripts
- README

### Phase 2

- recursive domain models
- layout helpers
- tile frame resolution
- unit tests

### Phase 3

- display discovery
- display assignment logic
- copied / mirrored profile model
- display settings UI

### Phase 4

- accessibility permission flow
- focused window lookup
- move / resize control
- graceful failure behavior

### Phase 5

- shortcut model
- bindings
- global hotkey registration
- tile action execution
- maximize / display actions
- shortcut editor

### Phase 6

- menu bar workflows
- layout selection
- display actions
- permission status exposure

### Phase 7

- polish
- persistence cleanup
- onboarding refinement
- final README
- final build verification

## 17. Definition of v1 Done

TileMe v1 is done when it:

- compiles cleanly
- launches as a menu bar app
- opens a preferences window
- detects displays
- includes predefined layouts
- resolves layouts using recursive split trees
- moves the focused window into a selected tile
- maximizes a focused window
- moves a focused window to another display
- stores layouts and shortcuts locally
- shows permission status and onboarding guidance
