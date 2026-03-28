import Combine
import Foundation

@MainActor
final class ShortcutCoordinator: ObservableObject {
    @Published private(set) var registrationFailures: [HotkeyRegistrationFailure] = []
    @Published private(set) var lastExecutionError: ShortcutExecutionError?
    @Published private(set) var lastExecutionMessage: String?

    private let workspaceStore: WorkspaceStore
    private let planner: ShortcutRegistrationPlanner
    private let hotkeyManager: any GlobalHotkeyManaging
    private let actionExecutor: any ShortcutActionExecuting
    private var cancellables = Set<AnyCancellable>()

    init(
        workspaceStore: WorkspaceStore,
        planner: ShortcutRegistrationPlanner = ShortcutRegistrationPlanner(),
        hotkeyManager: any GlobalHotkeyManaging = CarbonGlobalHotkeyManager(),
        actionExecutor: any ShortcutActionExecuting
    ) {
        self.workspaceStore = workspaceStore
        self.planner = planner
        self.hotkeyManager = hotkeyManager
        self.actionExecutor = actionExecutor

        workspaceStore.$profile
            .removeDuplicates()
            .sink { [weak self] profile in
                self?.reloadRegistrations(for: profile)
            }
            .store(in: &cancellables)

        reloadRegistrations(for: workspaceStore.profile)
    }

    func restoreDefaults() {
        workspaceStore.restoreDefaultShortcuts()
    }

    private func reloadRegistrations(for profile: WorkspaceProfile) {
        let plannedRegistrations = planner.registrations(for: profile)
        let registrations = plannedRegistrations.map { registration in
            GlobalHotkeyRegistration(
                identifier: registration.identifier,
                keyCode: registration.keyCode,
                modifiersRawValue: registration.modifiersRawValue,
                handler: { [weak self] in
                    self?.execute(registration.command)
                }
            )
        }

        registrationFailures = hotkeyManager.replaceRegistrations(registrations)
    }

    private func execute(_ command: ShortcutCommand) {
        switch actionExecutor.execute(command, workspaceProfile: workspaceStore.profile) {
        case let .success(snapshot):
            lastExecutionError = nil
            lastExecutionMessage = snapshot.fitEvaluation?.conciseMessage
        case let .failure(error):
            lastExecutionError = error
            lastExecutionMessage = nil
        }
    }
}
