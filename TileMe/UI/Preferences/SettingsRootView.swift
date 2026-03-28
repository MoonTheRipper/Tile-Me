import AppKit
import SwiftUI

struct SettingsRootView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var displayManager: DisplayManager
    @EnvironmentObject private var releaseExperienceController: ReleaseExperienceController
    @EnvironmentObject private var updateController: UpdateController
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var accessibilityPermissionStore: AccessibilityPermissionStore

    var body: some View {
        Form {
            PreferencesSection(title: "Overview", summary: "Tile Me is a native menu bar tiling app that keeps layouts and shortcuts local to this Mac.") {
                SettingsOverviewView()
            }

            PreferencesSection(title: "Permissions", summary: permissionsSummary) {
                AccessibilityOnboardingView()
            }

            PreferencesSection(title: "Updates", summary: "Check GitHub releases for newer versions and open the download page when an update is available.") {
                UpdatesSettingsView()
            }

            PreferencesSection(title: "Displays", summary: "Assign a layout per display, or reuse another display's layout by copying or mirroring it.") {
                DisplayAssignmentsView()
            }

            PreferencesSection(title: "Shortcuts", summary: "Configure global shortcuts for directional traversal, direct tile moves, maximize, and moving windows between displays.") {
                ShortcutEditorView()
            }

            PreferencesSection(title: "Layouts", summary: "V1 ships built-in recursive split-tree layouts and keeps the layout engine ready for deeper nested custom layouts later.") {
                BuiltinLayoutSummaryView()
            }

            #if DEBUG
            PreferencesSection(title: "Diagnostics", summary: "Use this when Accessibility still fails while debugging from Xcode or when a stale permission entry might still be in the way.") {
                AccessibilityDiagnosticsView()
            }
            #endif
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(minWidth: 640, minHeight: 560)
        .onAppear {
            displayManager.refreshDisplays()
            accessibilityPermissionStore.refreshStatus()
        }
    }

    private var permissionsSummary: String {
        accessibilityPermissionStore.status.isGranted
            ? "Accessibility access is enabled for focused-window inspection and window movement."
            : "Accessibility access is required before Tile Me can inspect or move another app's windows."
    }
}

private struct SettingsOverviewView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var displayManager: DisplayManager
    @EnvironmentObject private var releaseExperienceController: ReleaseExperienceController
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var accessibilityPermissionStore: AccessibilityPermissionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Version") {
                Text(appModel.versionDescription)
            }

            LabeledContent("Connected Displays") {
                Text("\(displayManager.displays.count)")
            }

            LabeledContent("Accessibility") {
                Text(accessibilityPermissionStore.status.isGranted ? "Enabled" : "Needed")
            }

            LabeledContent("Stored Locally") {
                Text("Display assignments and shortcut bindings")
                    .multilineTextAlignment(.trailing)
            }

            if !workspaceStore.profile.displayAssignments.isEmpty {
                LabeledContent("Assigned Displays") {
                    Text("\(workspaceStore.profile.displayAssignments.count)")
                }
            }

            LabeledContent("Help") {
                Button("Open Quick Start…") {
                    releaseExperienceController.presentHelp()
                }
            }

            LabeledContent("Support") {
                Button("Open Support…") {
                    releaseExperienceController.presentSupport()
                }
            }
        }
        .controlSize(.small)
    }
}

private struct BuiltinLayoutSummaryView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Built-in presets: Halves, 2x2, 3x3, and 4x4.")

            Text("Nested split examples already exist in the domain layer and tests, so future custom layouts can grow from the same tree model without replacing the engine.")
                .foregroundStyle(.secondary)

            Text("The menu keeps quick selection focused on built-in presets in v1.0.1.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct UpdatesSettingsView: View {
    @EnvironmentObject private var updateController: UpdateController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(
                "Check for updates automatically",
                isOn: Binding(
                    get: { updateController.automaticallyChecksEnabled },
                    set: { updateController.setAutomaticallyChecksEnabled($0) }
                )
            )

            HStack(spacing: 8) {
                Button(updateController.isCheckingForUpdates ? "Checking for Updates…" : "Check for Updates…") {
                    updateController.checkForUpdatesManually()
                }
                .disabled(updateController.isCheckingForUpdates)
            }

            Text("Downloads open in your default browser.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .controlSize(.small)
    }
}

#if DEBUG
private struct AccessibilityDiagnosticsView: View {
    @EnvironmentObject private var permissionStore: AccessibilityPermissionStore
    @State private var copiedDiagnostics = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preferred first test: launch Tile Me.app directly from Finder when checking Accessibility-dependent behavior.")
                .foregroundStyle(.secondary)

            Text("When running from Xcode, the DerivedData build may appear as a separate binary and may need its own Accessibility approval.")
                .foregroundStyle(.secondary)

            LabeledContent("Trust State") {
                Text(permissionStore.status.isGranted ? "Trusted" : "Not Trusted")
            }

            LabeledContent("Bundle Identifier") {
                Text(permissionStore.diagnosticBundleIdentifier)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }

            LabeledContent("Executable Path") {
                Text(permissionStore.diagnosticExecutablePath)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }

            Text("If Tile Me still reports denied access after you grant permission, remove any stale Tile Me entry in Accessibility, re-add the current build, then recheck status.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("Recheck Accessibility Status") {
                    permissionStore.refreshStatus()
                }

                Button("Open Accessibility Settings") {
                    _ = permissionStore.openAccessibilitySettings()
                }

                Button(copiedDiagnostics ? "Copied" : "Copy Diagnostics") {
                    copyDiagnostics()
                }
            }
            .controlSize(.small)
        }
        .controlSize(.small)
    }

    private var diagnosticsText: String {
        """
        Tile Me Accessibility Diagnostics
        Trust State: \(permissionStore.status.isGranted ? "Trusted" : "Not Trusted")
        Bundle Identifier: \(permissionStore.diagnosticBundleIdentifier)
        Executable Path: \(permissionStore.diagnosticExecutablePath)
        """
    }

    private func copyDiagnostics() {
        permissionStore.refreshStatus()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(diagnosticsText, forType: .string)

        copiedDiagnostics = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
        copiedDiagnostics = false
        }
    }
}
#endif

private struct DisplayAssignmentsView: View {
    @EnvironmentObject private var displayManager: DisplayManager
    @EnvironmentObject private var workspaceStore: WorkspaceStore

    var body: some View {
        if displayManager.displays.isEmpty {
            Text("No displays detected.")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(displayManager.displays) { display in
                    DisplayAssignmentCard(display: display, allDisplays: displayManager.displays)
                }
            }
        }
    }
}

private struct DisplayAssignmentCard: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore

    let display: DisplayProfile
    let allDisplays: [DisplayProfile]

    private var otherDisplays: [DisplayProfile] {
        allDisplays.filter { $0.id != display.id }
    }

    private var assignmentDescription: String {
        guard let assignment = workspaceStore.profile.assignment(for: display.id) else {
            return "Own layout: \(layoutName(for: workspaceStore.profile.resolvedLayoutID(for: display.id)))"
        }

        switch assignment.source {
        case let .layout(id):
            return "Own layout: \(layoutName(for: id))"
        case let .copied(sourceDisplayID, layoutID):
            return "Copied from \(displayName(for: sourceDisplayID)): \(layoutName(for: layoutID))"
        case let .mirrored(sourceDisplayID):
            let mirroredLayoutID = workspaceStore.profile.resolvedLayoutID(for: display.id)
            return "Mirrors \(displayName(for: sourceDisplayID)): \(layoutName(for: mirroredLayoutID))"
        }
    }

    private var selectedLayoutID: Binding<String> {
        Binding(
            get: {
                workspaceStore.profile.directLayoutID(for: display.id) ??
                    workspaceStore.profile.resolvedLayoutID(for: display.id)
            },
            set: { newLayoutID in
                workspaceStore.setLayout(id: newLayoutID, for: display.id)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(display.name)
                    .font(.headline)

                Text(display.typeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(display.scaleDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Usable \(display.visibleFrameSizeDescription), full frame \(display.frameSizeDescription)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(assignmentDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Layout", selection: selectedLayoutID) {
                ForEach(BuiltinLayouts.all) { layout in
                    Text(layout.name).tag(layout.id)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.small)

            HStack(spacing: 8) {
                Menu("Copy Layout From") {
                    if otherDisplays.isEmpty {
                        Button("No Other Display") {}
                            .disabled(true)
                    } else {
                        ForEach(otherDisplays) { sourceDisplay in
                            Button(sourceDisplay.name) {
                                workspaceStore.copyLayout(from: sourceDisplay.id, to: display.id)
                            }
                        }
                    }
                }

                Menu("Mirror Display") {
                    if otherDisplays.isEmpty {
                        Button("No Other Display") {}
                            .disabled(true)
                    } else {
                        ForEach(otherDisplays) { sourceDisplay in
                            Button(sourceDisplay.name) {
                                workspaceStore.mirrorLayout(from: sourceDisplay.id, to: display.id)
                            }
                        }
                    }
                }

                if workspaceStore.profile.mode(for: display.id) != .ownLayout {
                    Button("Use Own Layout") {
                        workspaceStore.promoteResolvedLayoutToOwn(for: display.id)
                    }
                }
            }
            .controlSize(.small)
        }
        .padding(.vertical, 6)
    }

    private func displayName(for displayID: String) -> String {
        allDisplays.first(where: { $0.id == displayID })?.name ?? displayID
    }

    private func layoutName(for layoutID: String) -> String {
        BuiltinLayouts.definition(id: layoutID)?.name ?? layoutID
    }
}
