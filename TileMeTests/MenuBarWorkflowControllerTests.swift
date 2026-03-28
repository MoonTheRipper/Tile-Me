import CoreGraphics
import XCTest
@testable import TileMe

@MainActor
final class MenuBarWorkflowControllerTests: XCTestCase {
    func testRefreshFocusedWindowStateResolvesDisplayAndLayout() {
        let displays = [
            DisplayProfile(
                id: "main",
                name: "Main",
                frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
                visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 760),
                scale: 2,
                isBuiltIn: true
            )
        ]
        let workspaceStore = WorkspaceStore(defaults: isolatedDefaults(), storageKey: "menu-workflow-refresh")
        workspaceStore.setLayout(id: BuiltinLayouts.grid2x2.id, for: "main")
        let controller = MenuBarWorkflowController(
            workspaceStore: workspaceStore,
            permissionStore: AccessibilityPermissionStore(
                checker: MenuBarTestPermissionChecker(currentStatusValue: .granted),
                settingsOpener: MenuBarTestSettingsOpener()
            ),
            displayProvider: MenuBarTestDisplayProvider(displays: displays),
            windowCommands: MenuBarTestWindowCommands(
                result: .success(
                    FocusedWindowSnapshot(
                        application: FocusedApplication(processID: 42, localizedName: "Preview", bundleIdentifier: nil),
                        title: "Document",
                        frame: CGRect(x: 100, y: 100, width: 500, height: 400),
                        isMovable: true,
                        isResizable: true
                    )
                )
            ),
            actionExecutor: MenuBarTestActionExecutor()
        )

        controller.refreshFocusedWindowState()

        XCTAssertEqual(controller.focusedWindowSnapshot?.application.localizedName, "Preview")
        XCTAssertEqual(controller.focusedDisplay?.id, "main")
        XCTAssertEqual(controller.focusedLayout?.id, BuiltinLayouts.grid2x2.id)
        XCTAssertEqual(controller.focusedTileIndices, [0, 1, 2, 3])
    }

    func testDisplayActionsUpdateWorkspaceProfile() {
        let workspaceStore = WorkspaceStore(defaults: isolatedDefaults(), storageKey: "menu-workflow-layouts")
        let displays = [
            DisplayProfile(
                id: "main",
                name: "Main",
                frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
                visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 760),
                scale: 2,
                isBuiltIn: true
            ),
            DisplayProfile(
                id: "external",
                name: "External",
                frame: CGRect(x: 1200, y: 0, width: 1440, height: 900),
                visibleFrame: CGRect(x: 1200, y: 0, width: 1440, height: 860),
                scale: 2,
                isBuiltIn: false
            )
        ]
        let controller = MenuBarWorkflowController(
            workspaceStore: workspaceStore,
            permissionStore: AccessibilityPermissionStore(
                checker: MenuBarTestPermissionChecker(currentStatusValue: .granted),
                settingsOpener: MenuBarTestSettingsOpener()
            ),
            displayProvider: MenuBarTestDisplayProvider(displays: displays),
            windowCommands: MenuBarTestWindowCommands(result: .failure(.noFocusedWindow)),
            actionExecutor: MenuBarTestActionExecutor()
        )

        controller.apply(layoutID: BuiltinLayouts.grid3x3.id, to: "main")
        controller.copyLayout(from: "main", to: "external")

        XCTAssertEqual(workspaceStore.profile.resolvedLayoutID(for: "main"), BuiltinLayouts.grid3x3.id)
        XCTAssertEqual(workspaceStore.profile.mode(for: "external"), .copiedLayout)
        XCTAssertEqual(workspaceStore.profile.resolvedLayoutID(for: "external"), BuiltinLayouts.grid3x3.id)
    }

    func testPerformStoresLastActionError() {
        let workspaceStore = WorkspaceStore(defaults: isolatedDefaults(), storageKey: "menu-workflow-actions")
        let controller = MenuBarWorkflowController(
            workspaceStore: workspaceStore,
            permissionStore: AccessibilityPermissionStore(
                checker: MenuBarTestPermissionChecker(currentStatusValue: .granted),
                settingsOpener: MenuBarTestSettingsOpener()
            ),
            displayProvider: MenuBarTestDisplayProvider(displays: []),
            windowCommands: MenuBarTestWindowCommands(result: .failure(.permissionDenied)),
            actionExecutor: MenuBarTestActionExecutor(result: .failure(.noTargetDisplay))
        )

        controller.perform(.maximize)

        XCTAssertEqual(controller.lastActionError, .noTargetDisplay)
    }

    func testPerformStoresLastActionMessageForConstrainedFit() {
        let workspaceStore = WorkspaceStore(defaults: isolatedDefaults(), storageKey: "menu-workflow-constrained")
        let controller = MenuBarWorkflowController(
            workspaceStore: workspaceStore,
            permissionStore: AccessibilityPermissionStore(
                checker: MenuBarTestPermissionChecker(currentStatusValue: .granted),
                settingsOpener: MenuBarTestSettingsOpener()
            ),
            displayProvider: MenuBarTestDisplayProvider(displays: []),
            windowCommands: MenuBarTestWindowCommands(result: .failure(.permissionDenied)),
            actionExecutor: MenuBarTestActionExecutor(
                result: .success(
                    FocusedWindowSnapshot(
                        application: FocusedApplication(processID: 42, localizedName: "Terminal", bundleIdentifier: nil),
                        title: "Shell",
                        frame: CGRect(x: 0, y: 0, width: 520, height: 320),
                        isMovable: true,
                        isResizable: true,
                        fitEvaluation: WindowFitEvaluation(
                            status: .constrainedFit,
                            intendedFrame: CGRect(x: 0, y: 0, width: 320, height: 200),
                            requestedFrame: CGRect(x: 0, y: 0, width: 320, height: 200),
                            actualFrame: CGRect(x: 0, y: 0, width: 520, height: 320),
                            maxOriginDelta: 0,
                            maxSizeDelta: 200,
                            maxEdgeDelta: 200,
                            overlapRatio: 1,
                            normalizedCenterDistance: 0,
                            isSmallTarget: false
                        )
                    )
                )
            )
        )

        controller.perform(.maximize)

        XCTAssertEqual(controller.lastActionMessage, "Window did not fully fit the target frame.")
        XCTAssertNil(controller.lastActionError)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "TileMeTests.MenuBarWorkflow.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private struct MenuBarTestDisplayProvider: DisplayProviding {
    let displays: [DisplayProfile]

    func display(containing frame: CGRect) -> DisplayProfile? {
        let midpoint = CGPoint(x: frame.midX, y: frame.midY)
        return displays.first(where: { $0.frame.contains(midpoint) })
    }

    func nextDisplay(after displayID: String?) -> DisplayProfile? {
        guard !displays.isEmpty else {
            return nil
        }

        guard let displayID, let index = displays.firstIndex(where: { $0.id == displayID }) else {
            return displays.first
        }

        let nextIndex = displays.index(after: index)
        return nextIndex < displays.endIndex ? displays[nextIndex] : displays.first
    }
}

private struct MenuBarTestWindowCommands: FocusedWindowCommandRunning {
    let result: Result<FocusedWindowSnapshot, AccessibilityWindowError>

    func inspectFocusedWindow() -> Result<FocusedWindowSnapshot, AccessibilityWindowError> {
        result
    }

    func moveFocusedWindow(to frame: CGRect) -> Result<FocusedWindowSnapshot, AccessibilityWindowError> {
        result
    }
}

private struct MenuBarTestActionExecutor: ShortcutActionExecuting {
    var result: Result<FocusedWindowSnapshot, ShortcutExecutionError> = .success(
        FocusedWindowSnapshot(
            application: FocusedApplication(processID: 42, localizedName: "Preview", bundleIdentifier: nil),
            title: "Document",
            frame: CGRect(x: 0, y: 0, width: 600, height: 760),
            isMovable: true,
            isResizable: true
        )
    )

    func execute(
        _ command: ShortcutCommand,
        workspaceProfile: WorkspaceProfile
    ) -> Result<FocusedWindowSnapshot, ShortcutExecutionError> {
        result
    }
}

private struct MenuBarTestPermissionChecker: AccessibilityPermissionChecking {
    let currentStatusValue: AccessibilityPermissionStatus

    func currentStatus() -> AccessibilityPermissionStatus {
        currentStatusValue
    }

    func requestPermission() -> AccessibilityPermissionStatus {
        currentStatusValue
    }
}

private struct MenuBarTestSettingsOpener: AccessibilitySettingsOpening {
    func openAccessibilitySettings() -> Bool {
        true
    }
}
