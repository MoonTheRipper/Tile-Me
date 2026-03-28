import Foundation

@MainActor
final class MenuBarWorkflowController: ObservableObject {
    @Published private(set) var focusedWindowSnapshot: FocusedWindowSnapshot?
    @Published private(set) var focusedWindowError: AccessibilityWindowError?
    @Published private(set) var lastActionError: ShortcutExecutionError?
    @Published private(set) var lastActionMessage: String?

    private let workspaceStore: WorkspaceStore
    private let permissionStore: AccessibilityPermissionStore
    private let displayProvider: any DisplayProviding
    private let windowCommands: any FocusedWindowCommandRunning
    private let actionExecutor: any ShortcutActionExecuting

    init(
        workspaceStore: WorkspaceStore,
        permissionStore: AccessibilityPermissionStore,
        displayProvider: any DisplayProviding,
        windowCommands: any FocusedWindowCommandRunning = FocusedWindowCommandRunner(),
        actionExecutor: any ShortcutActionExecuting
    ) {
        self.workspaceStore = workspaceStore
        self.permissionStore = permissionStore
        self.displayProvider = displayProvider
        self.windowCommands = windowCommands
        self.actionExecutor = actionExecutor
    }

    var focusedDisplay: DisplayProfile? {
        guard let snapshot = focusedWindowSnapshot else {
            return nil
        }

        return displayProvider.display(containing: snapshot.frame) ?? displayProvider.displays.first
    }

    var focusedLayout: LayoutDefinition? {
        guard let display = focusedDisplay else {
            return nil
        }

        let layoutID = workspaceStore.profile.resolvedLayoutID(for: display.id)
        return BuiltinLayouts.definition(id: layoutID) ?? BuiltinLayouts.defaultLayout
    }

    var focusedTileIndices: [Int] {
        Array(0..<(focusedLayout?.tileCount ?? 0))
    }

    func refreshFocusedWindowState() {
        switch windowCommands.inspectFocusedWindow() {
        case let .success(snapshot):
            focusedWindowSnapshot = snapshot
            focusedWindowError = nil
            lastActionError = nil
            lastActionMessage = nil
        case let .failure(error):
            focusedWindowSnapshot = nil
            focusedWindowError = error
            lastActionMessage = nil
            if error == .permissionDenied {
                permissionStore.refreshStatus()
            }
        }
    }

    func apply(layoutID: String, to displayID: String) {
        workspaceStore.setLayout(id: layoutID, for: displayID)
    }

    func copyLayout(from sourceDisplayID: String, to targetDisplayID: String) {
        guard sourceDisplayID != targetDisplayID else {
            return
        }

        workspaceStore.copyLayout(from: sourceDisplayID, to: targetDisplayID)
    }

    func useOwnLayout(for displayID: String) {
        workspaceStore.promoteResolvedLayoutToOwn(for: displayID)
    }

    func assignmentDescription(for display: DisplayProfile, availableDisplays: [DisplayProfile]) -> String {
        guard let assignment = workspaceStore.profile.assignment(for: display.id) else {
            return "Own Layout: \(layoutName(for: workspaceStore.profile.resolvedLayoutID(for: display.id)))"
        }

        switch assignment.source {
        case let .layout(id):
            return "Own Layout: \(layoutName(for: id))"
        case let .copied(sourceDisplayID, layoutID):
            return "Copied from \(displayName(for: sourceDisplayID, availableDisplays: availableDisplays)): \(layoutName(for: layoutID))"
        case let .mirrored(sourceDisplayID):
            let resolvedLayoutID = workspaceStore.profile.resolvedLayoutID(for: display.id)
            return "Mirrors \(displayName(for: sourceDisplayID, availableDisplays: availableDisplays)): \(layoutName(for: resolvedLayoutID))"
        }
    }

    func perform(_ action: ShortcutAction) {
        execute(.action(action))
    }

    func moveFocusedWindowToTile(index: Int) {
        execute(.action(.moveToTile(index: index)))
    }

    private func execute(_ command: ShortcutCommand) {
        switch actionExecutor.execute(command, workspaceProfile: workspaceStore.profile) {
        case let .success(snapshot):
            focusedWindowSnapshot = snapshot
            focusedWindowError = nil
            lastActionError = nil
            lastActionMessage = snapshot.fitEvaluation?.conciseMessage
        case let .failure(error):
            lastActionError = error
            lastActionMessage = nil
            if case .accessibility(.permissionDenied) = error {
                permissionStore.refreshStatus()
            }
        }
    }

    private func displayName(for displayID: String, availableDisplays: [DisplayProfile]) -> String {
        availableDisplays.first(where: { $0.id == displayID })?.name ?? displayID
    }

    private func layoutName(for layoutID: String) -> String {
        BuiltinLayouts.definition(id: layoutID)?.name ?? layoutID
    }
}
