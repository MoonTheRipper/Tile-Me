# TileMe Implementation Tasks

## Phase 0 — Planning Only

- [x] Rewrite `SPEC.md` to match the recursive split-tree architecture and phased plan
- [x] Rewrite `TASKS.md` into a strict implementation checklist
- [x] Produce a concise implementation plan
- [x] Stop after planning

## Phase 1 — Project Scaffolding

- [x] Create native macOS SwiftUI Xcode project
- [x] Create the target folder structure
- [x] Add app shell under `TileMe/App`
- [x] Add menu bar shell under `TileMe/UI/MenuBar`
- [x] Add preferences shell under `TileMe/UI/Preferences`
- [x] Add onboarding shell under `TileMe/UI/Onboarding`
- [x] Add shared UI components folder under `TileMe/UI/Components`
- [x] Add domain folders:
- [x] `TileMe/Domain/Models`
- [x] `TileMe/Domain/LayoutEngine`
- [x] `TileMe/Domain/DisplayEngine`
- [x] `TileMe/Domain/ShortcutEngine`
- [x] `TileMe/Domain/WorkspaceEngine`
- [x] Add infrastructure folders:
- [x] `TileMe/Infrastructure/Accessibility`
- [x] `TileMe/Infrastructure/Persistence`
- [x] `TileMe/Infrastructure/Hotkeys`
- [x] `TileMe/Infrastructure/System`
- [x] Add `Scripts/build.sh`
- [x] Add `Scripts/run.sh`
- [x] Add `Scripts/test.sh`
- [x] Add `README.md`
- [x] Validate project structure
- [x] Run the narrowest build possible
- [x] Stop and report

## Phase 2 — Domain Models And Tiling Engine

- [x] Implement `TileNode`
- [x] Implement `LayoutDefinition`
- [x] Implement `TileFrame`
- [x] Implement stable identifiers for layout nodes and leaf tiles
- [x] Implement equal split helpers
- [x] Implement left/right halves helper
- [x] Implement `2x2` helper
- [x] Implement `3x3` helper
- [x] Implement `4x4` helper
- [x] Make helper design ready for `8x8`
- [x] Implement recursive layout resolution into absolute frames
- [x] Add nested uneven layout examples
- [x] Add tests for grid helper generation
- [x] Add tests for nested split resolution
- [x] Add tests for stable identifier preservation where practical
- [x] Run tests
- [x] Stop and report

## Phase 3 — Display Profile System

- [x] Implement display discovery abstraction
- [x] Implement `DisplayProfile`
- [x] Implement workspace/display assignment logic
- [x] Implement own-layout display mode
- [x] Implement copied-layout display mode
- [x] Model mirrored display profile behavior
- [x] Add persistence hooks for display assignments
- [x] Add settings UI to inspect displays
- [x] Run build and targeted tests
- [x] Stop and report

## Phase 4 — Accessibility Window Control

- [x] Implement permission trust-state service
- [x] Implement focused app lookup
- [x] Implement focused window lookup
- [x] Implement move/resize focused window
- [x] Implement maximize / fullscreen-style placement
- [x] Add protocol-based abstractions for testability
- [x] Add graceful unsupported-window handling
- [x] Add permissions UI section
- [x] Run build and targeted tests
- [x] Stop and report

## Phase 5 — Shortcut System

- [x] Implement `ShortcutAction`
- [x] Implement `ShortcutBinding`
- [x] Implement structured shortcut map
- [x] Persist shortcut bindings
- [x] Implement global hotkey registration
- [x] Implement tile shortcut execution
- [x] Implement maximize shortcut execution
- [x] Implement next-display shortcut execution
- [x] Implement additional-modifier path for same tile on another display
- [x] Add shortcut editor UI
- [x] Run build and targeted tests
- [x] Stop and report

## Phase 6 — Menu Bar Workflows

- [x] Implement menu bar quick actions
- [x] Implement quick layout selection per display
- [x] Implement copy-layout-to-display workflow
- [x] Keep mirror-profile editing in Settings to avoid bloating the menu
- [x] Implement open-settings action
- [x] Implement permission status visibility in menu
- [x] Implement focused-window tile actions from menu if practical
- [x] Run build and targeted tests
- [x] Stop and report

## Phase 7 — Polish For First Working Version

- [x] Clean up persistence behavior
- [x] Refine onboarding copy
- [x] Organize settings sections cleanly
- [x] Keep the SF Symbol menu bar icon placeholder for v1
- [x] Apply restrained UX polish
- [x] Finalize `README.md`
- [x] Final build verification
- [x] Stop and provide v1 summary
