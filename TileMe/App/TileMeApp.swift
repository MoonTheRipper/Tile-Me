import AppKit
import SwiftUI

@main
struct TileMeApp: App {
    @StateObject private var appModel: AppModel
    @StateObject private var displayManager: DisplayManager
    @StateObject private var releaseExperienceController: ReleaseExperienceController
    @StateObject private var updateController: UpdateController
    @StateObject private var workspaceStore: WorkspaceStore
    @StateObject private var accessibilityPermissionStore: AccessibilityPermissionStore
    @StateObject private var shortcutCoordinator: ShortcutCoordinator
    @StateObject private var menuBarWorkflowController: MenuBarWorkflowController

    init() {
        let appModel = AppModel()
        let displayManager = DisplayManager()
        let releaseExperienceController = ReleaseExperienceController()
        let updateController = UpdateController(currentVersionString: appModel.versionString)
        let workspaceStore = WorkspaceStore()
        let accessibilityPermissionStore = AccessibilityPermissionStore()
        let shortcutActionExecutor = ShortcutActionExecutor(displayProvider: displayManager)
        let shortcutCoordinator = ShortcutCoordinator(
            workspaceStore: workspaceStore,
            actionExecutor: shortcutActionExecutor
        )
        let menuBarWorkflowController = MenuBarWorkflowController(
            workspaceStore: workspaceStore,
            permissionStore: accessibilityPermissionStore,
            displayProvider: displayManager,
            actionExecutor: shortcutActionExecutor
        )

        _appModel = StateObject(wrappedValue: appModel)
        _displayManager = StateObject(wrappedValue: displayManager)
        _releaseExperienceController = StateObject(wrappedValue: releaseExperienceController)
        _updateController = StateObject(wrappedValue: updateController)
        _workspaceStore = StateObject(wrappedValue: workspaceStore)
        _accessibilityPermissionStore = StateObject(wrappedValue: accessibilityPermissionStore)
        _shortcutCoordinator = StateObject(wrappedValue: shortcutCoordinator)
        _menuBarWorkflowController = StateObject(wrappedValue: menuBarWorkflowController)

        DispatchQueue.main.async {
            releaseExperienceController.presentWelcomeIfNeeded()
            updateController.scheduleAutomaticLaunchCheck()
        }
    }

    var body: some Scene {
        MenuBarExtra("Tile Me", systemImage: "rectangle.split.2x1") {
            MenuBarContentView()
                .environmentObject(appModel)
                .environmentObject(displayManager)
                .environmentObject(releaseExperienceController)
                .environmentObject(updateController)
                .environmentObject(workspaceStore)
                .environmentObject(accessibilityPermissionStore)
                .environmentObject(menuBarWorkflowController)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsRootView()
                .environmentObject(appModel)
                .environmentObject(displayManager)
                .environmentObject(releaseExperienceController)
                .environmentObject(updateController)
                .environmentObject(workspaceStore)
                .environmentObject(accessibilityPermissionStore)
                .environmentObject(shortcutCoordinator)
        }
    }
}
