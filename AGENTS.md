# TileMe Agent Rules

These rules apply to any coding agent working in this repository.

## Stack And Product Boundaries

- Preserve the native macOS stack: Swift, SwiftUI, Xcode project, and `xcodebuild`.
- Keep TileMe a menu bar-first macOS app.
- Keep the app lightweight in launch time, idle behavior, CPU use, and memory use.
- Do not switch stacks.
- Do not add unnecessary dependencies.
- Do not add unrelated features, services, or product surfaces.

## Delivery Strategy

- Follow the phased build strategy defined in `SPEC.md` and `TASKS.md`.
- Work incrementally.
- Do not do speculative rewrites.
- Do not jump ahead across phases without explicit instruction.
- After each phase, stop and report clearly.

## Tiling Engine Rule

- Treat the tiling engine as a recursive split-tree system from the start.
- Do not model layouts as grid-only data.
- Grids may exist only as helpers that generate recursive split trees.
- Preserve stable identifiers for layout nodes and tiles wherever the model requires them.

## Validation Rule

- After meaningful changes, run the smallest relevant build or test step.
- If a build or test fails, fix it before continuing.
- Prefer `xcodebuild`-based validation.
- Keep `Scripts/build.sh`, `Scripts/run.sh`, and `Scripts/test.sh` working.

## UI Rule

- Keep the UI restrained, native, and modern in macOS style.
- Avoid oversized windows.
- Avoid bloated settings UI.
- Prefer standard macOS controls and sensible spacing.
- Do not add flashy or non-native visual treatments.

## Code Quality Rule

- Prefer modular, testable code.
- Keep naming clear and direct.
- Add comments only when they clarify non-obvious logic.
- Maintain a clean project structure.
- Do not leave dead files behind.
- Do not silently skip required features.

## Reporting Rule

- Summarize what changed at the end of each phase.
- List files created or changed.
- List validation commands run.
- State current status and stop after the requested phase.
