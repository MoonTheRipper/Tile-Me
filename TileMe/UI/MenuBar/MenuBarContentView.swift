import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var displayManager: DisplayManager
    @EnvironmentObject private var releaseExperienceController: ReleaseExperienceController
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var accessibilityPermissionStore: AccessibilityPermissionStore
    @EnvironmentObject private var menuBarWorkflowController: MenuBarWorkflowController

    var body: some View {
        Group {
            Text(appModel.appName)
                .font(.headline)

            Text(appModel.versionDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(displaySummary)
                .foregroundStyle(.secondary)

            Divider()

            accessibilityMenu
            focusedWindowMenu

            if displayManager.displays.isEmpty {
                Text("No displays detected.")
                    .foregroundStyle(.secondary)
            } else {
                Divider()

                ForEach(displayManager.displays) { display in
                    displayMenu(for: display)
                }
            }

            Divider()

            Button("Help / Quick Start…") {
                releaseExperienceController.presentHelp()
            }

            Button("Support…") {
                releaseExperienceController.presentSupport()
            }

            SettingsLink {
                Text("Settings…")
            }

            Button("Quit Tile Me") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .onAppear {
            displayManager.refreshDisplays()
            accessibilityPermissionStore.refreshStatus()
            menuBarWorkflowController.refreshFocusedWindowState()
        }
    }

    private var displaySummary: String {
        "\(displayManager.displays.count) display\(displayManager.displays.count == 1 ? "" : "s") connected"
    }

    private var accessibilityMenu: some View {
        Menu {
            Text(accessibilityPermissionStore.status.detail)
                .foregroundStyle(.secondary)

            if !accessibilityPermissionStore.status.isGranted {
                Button("Request Accessibility Access") {
                    accessibilityPermissionStore.requestPermission()
                    menuBarWorkflowController.refreshFocusedWindowState()
                }

                Button("Open Accessibility Settings") {
                    _ = accessibilityPermissionStore.openAccessibilitySettings()
                }
            }

            Button("Recheck Accessibility Status") {
                accessibilityPermissionStore.refreshStatus()
                menuBarWorkflowController.refreshFocusedWindowState()
            }
        } label: {
            Label(
                accessibilityPermissionStore.status.isGranted ? "Accessibility Enabled" : "Accessibility Required",
                systemImage: accessibilityPermissionStore.status.symbolName
            )
        }
    }

    private var focusedWindowMenu: some View {
        Menu {
            if let snapshot = menuBarWorkflowController.focusedWindowSnapshot {
                Text(snapshot.application.localizedName)
                    .fontWeight(.semibold)

                if let title = snapshot.title, !title.isEmpty {
                    Text(title)
                        .foregroundStyle(.secondary)
                }

                if let display = menuBarWorkflowController.focusedDisplay {
                    Text("\(display.name) · \(menuBarWorkflowController.focusedLayout?.name ?? BuiltinLayouts.defaultLayout.name)")
                        .foregroundStyle(.secondary)
                }

                Divider()

                Menu("Move to Tile") {
                    if menuBarWorkflowController.focusedTileIndices.isEmpty {
                        Text("No tiles available.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(menuBarWorkflowController.focusedTileIndices, id: \.self) { index in
                            Button("Tile \(index + 1)") {
                                menuBarWorkflowController.moveFocusedWindowToTile(index: index)
                            }
                            .disabled(!snapshot.isMovable || !snapshot.isResizable)
                        }
                    }
                }

                Button("Maximize") {
                    menuBarWorkflowController.perform(.maximize)
                }
                .disabled(!snapshot.isMovable || !snapshot.isResizable)

                Button("Move to Next Display") {
                    menuBarWorkflowController.perform(.moveToNextDisplay)
                }
                .disabled(displayManager.displays.count < 2 || !snapshot.isMovable || !snapshot.isResizable)

                Button("Move to Next Display and Preserve Tile") {
                    menuBarWorkflowController.perform(.moveToNextDisplayPreservingTile)
                }
                .disabled(displayManager.displays.count < 2 || !snapshot.isMovable || !snapshot.isResizable)
            } else {
                Text(menuBarWorkflowController.focusedWindowError?.errorDescription ?? "No focused window available.")
                    .foregroundStyle(.secondary)

                if !accessibilityPermissionStore.status.isGranted {
                    Button("Open Accessibility Settings") {
                        _ = accessibilityPermissionStore.openAccessibilitySettings()
                    }
                }
            }

            Divider()

                Button("Refresh Focused Window") {
                    menuBarWorkflowController.refreshFocusedWindowState()
                }

            if let error = menuBarWorkflowController.lastActionError {
                Divider()

                Text(error.errorDescription ?? "The last focused-window action failed.")
                    .foregroundStyle(.secondary)

                if case let .accessibility(accessibilityError) = error,
                   let recoverySuggestion = accessibilityError.recoverySuggestion {
                    Text(recoverySuggestion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let message = menuBarWorkflowController.lastActionMessage {
                Divider()

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } label: {
            Label("Focused Window", systemImage: "macwindow")
        }
    }

    private func displayMenu(for display: DisplayProfile) -> some View {
        let currentResolvedLayoutID = workspaceStore.profile.resolvedLayoutID(for: display.id)
        let otherDisplays = displayManager.otherDisplays(excluding: display.id)

        return Menu {
            Text(display.visibleFrameSizeDescription)
                .foregroundStyle(.secondary)

            Text(menuBarWorkflowController.assignmentDescription(for: display, availableDisplays: displayManager.displays))
                .foregroundStyle(.secondary)

            Divider()

            Menu("Apply Layout") {
                ForEach(BuiltinLayouts.all) { layout in
                    Button {
                        menuBarWorkflowController.apply(layoutID: layout.id, to: display.id)
                    } label: {
                        if currentResolvedLayoutID == layout.id {
                            Label(layout.name, systemImage: "checkmark")
                        } else {
                            Text(layout.name)
                        }
                    }
                }
            }

            Menu("Copy Layout From") {
                if otherDisplays.isEmpty {
                    Button("No Other Display") {}
                        .disabled(true)
                } else {
                    ForEach(otherDisplays) { sourceDisplay in
                        Button(sourceDisplay.name) {
                            menuBarWorkflowController.copyLayout(from: sourceDisplay.id, to: display.id)
                        }
                    }
                }
            }

            if workspaceStore.profile.mode(for: display.id) != .ownLayout {
                Button("Use Own Layout") {
                    menuBarWorkflowController.useOwnLayout(for: display.id)
                }
            }
        } label: {
            Label(display.name, systemImage: display.isBuiltIn ? "laptopcomputer" : "display")
        }
    }
}
