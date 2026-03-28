import CoreGraphics
import XCTest
@testable import TileMe

@MainActor
final class ShortcutEngineTests: XCTestCase {
    func testPlannerAddsNextDisplayVariantForTileBindingsWithAdditionalModifier() {
        var profile = WorkspaceProfile(shortcuts: [:])
        profile.setShortcut(
            ShortcutBinding(keyCode: 18, modifiersRawValue: 1 << 19, additionalDisplayModifiersRawValue: 1 << 17),
            for: .moveToTile(index: 0)
        )

        let registrations = ShortcutRegistrationPlanner().registrations(for: profile)

        XCTAssertEqual(registrations.count, 2)
        XCTAssertEqual(registrations[0].identifier, "tile.0")
        XCTAssertEqual(registrations[1].identifier, "tile.0.nextDisplay")
        XCTAssertEqual(registrations[1].modifiersRawValue, (1 << 19) | (1 << 17))
        XCTAssertEqual(registrations[1].command, .moveToTileOnNextDisplay(index: 0))
    }

    func testExecutorMovesFocusedWindowIntoConfiguredTile() {
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
        let commandRunner = RecordingWindowCommandRunner(
            snapshot: FocusedWindowSnapshot(
                application: FocusedApplication(processID: 42, localizedName: "Preview", bundleIdentifier: "com.apple.Preview"),
                title: "Document",
                frame: CGRect(x: 100, y: 100, width: 500, height: 500),
                isMovable: true,
                isResizable: true
            )
        )
        let executor = ShortcutActionExecutor(
            displayProvider: StubDisplayProvider(displays: displays),
            windowCommands: commandRunner
        )
        var profile = WorkspaceProfile(shortcuts: [:])
        profile.setLayout(id: BuiltinLayouts.halves.id, for: "main")

        let result = executor.execute(.action(.moveToTile(index: 0)), workspaceProfile: profile)

        XCTAssertNotNil(try? result.get())
        XCTAssertEqual(commandRunner.lastMovedFrame, CGRect(x: 0, y: 0, width: 600, height: 760))
    }

    func testExecutorMaximizesFocusedWindowInCurrentDisplay() {
        let display = DisplayProfile(
            id: "main",
            name: "Main",
            frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
            visibleFrame: CGRect(x: 0, y: 24, width: 1200, height: 736),
            scale: 2,
            isBuiltIn: true
        )
        let commandRunner = RecordingWindowCommandRunner(
            snapshot: FocusedWindowSnapshot(
                application: FocusedApplication(processID: 42, localizedName: "Preview", bundleIdentifier: "com.apple.Preview"),
                title: "Document",
                frame: CGRect(x: 150, y: 100, width: 500, height: 400),
                isMovable: true,
                isResizable: true
            )
        )
        let executor = ShortcutActionExecutor(
            displayProvider: StubDisplayProvider(displays: [display]),
            windowCommands: commandRunner
        )

        let result = executor.execute(.action(.maximize), workspaceProfile: WorkspaceProfile(shortcuts: [:]))

        XCTAssertNotNil(try? result.get())
        XCTAssertEqual(commandRunner.lastMovedFrame, display.visibleFrame)
    }

    func testExecutorMovesWindowToNextDisplayPreservingRelativePlacement() {
        let main = DisplayProfile(
            id: "main",
            name: "Main",
            frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 760),
            scale: 2,
            isBuiltIn: true
        )
        let external = DisplayProfile(
            id: "external",
            name: "External",
            frame: CGRect(x: 1200, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 1200, y: 0, width: 1440, height: 860),
            scale: 2,
            isBuiltIn: false
        )
        let commandRunner = RecordingWindowCommandRunner(
            snapshot: FocusedWindowSnapshot(
                application: FocusedApplication(processID: 42, localizedName: "Preview", bundleIdentifier: "com.apple.Preview"),
                title: "Document",
                frame: CGRect(x: 120, y: 76, width: 600, height: 380),
                isMovable: true,
                isResizable: true
            )
        )
        let executor = ShortcutActionExecutor(
            displayProvider: StubDisplayProvider(displays: [main, external]),
            windowCommands: commandRunner
        )

        let result = executor.execute(.action(.moveToNextDisplay), workspaceProfile: WorkspaceProfile(shortcuts: [:]))

        XCTAssertNotNil(try? result.get())
        XCTAssertEqual(commandRunner.lastMovedFrame?.size, CGSize(width: 600, height: 380))
        XCTAssertEqual(commandRunner.lastMovedFrame?.origin, CGPoint(x: 1368, y: 96))
    }

    func testExecutorMovesTileShortcutToNextDisplayWhenDerivedCommandIsUsed() {
        let main = DisplayProfile(
            id: "main",
            name: "Main",
            frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 760),
            scale: 2,
            isBuiltIn: true
        )
        let external = DisplayProfile(
            id: "external",
            name: "External",
            frame: CGRect(x: 1200, y: 0, width: 1200, height: 800),
            visibleFrame: CGRect(x: 1200, y: 0, width: 1200, height: 760),
            scale: 2,
            isBuiltIn: false
        )
        let commandRunner = RecordingWindowCommandRunner(
            snapshot: FocusedWindowSnapshot(
                application: FocusedApplication(processID: 42, localizedName: "Preview", bundleIdentifier: "com.apple.Preview"),
                title: "Document",
                frame: CGRect(x: 200, y: 100, width: 500, height: 400),
                isMovable: true,
                isResizable: true
            )
        )
        let executor = ShortcutActionExecutor(
            displayProvider: StubDisplayProvider(displays: [main, external]),
            windowCommands: commandRunner
        )
        var profile = WorkspaceProfile(shortcuts: [:])
        profile.setLayout(id: BuiltinLayouts.halves.id, for: "main")
        profile.setLayout(id: BuiltinLayouts.halves.id, for: "external")

        let result = executor.execute(.moveToTileOnNextDisplay(index: 1), workspaceProfile: profile)

        XCTAssertNotNil(try? result.get())
        XCTAssertEqual(commandRunner.lastMovedFrame, CGRect(x: 1800, y: 0, width: 600, height: 760))
    }

}

private struct StubDisplayProvider: DisplayProviding {
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

private final class RecordingWindowCommandRunner: FocusedWindowCommandRunning {
    let snapshot: FocusedWindowSnapshot
    private(set) var lastMovedFrame: CGRect?

    init(snapshot: FocusedWindowSnapshot) {
        self.snapshot = snapshot
    }

    func inspectFocusedWindow() -> Result<FocusedWindowSnapshot, AccessibilityWindowError> {
        .success(snapshot)
    }

    func moveFocusedWindow(to frame: CGRect) -> Result<FocusedWindowSnapshot, AccessibilityWindowError> {
        lastMovedFrame = frame
        return .success(
            FocusedWindowSnapshot(
                application: snapshot.application,
                title: snapshot.title,
                frame: frame,
                isMovable: snapshot.isMovable,
                isResizable: snapshot.isResizable
            )
        )
    }
}
