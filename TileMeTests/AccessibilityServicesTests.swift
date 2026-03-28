import CoreGraphics
import XCTest
@testable import TileMe

@MainActor
final class AccessibilityServicesTests: XCTestCase {
    func testAccessibilityCoordinateTransformerRoundTripsSingleDisplayFrames() {
        let transformer = AccessibilityCoordinateTransformer(
            screenFrames: [CGRect(x: 0, y: 0, width: 1200, height: 760)]
        )
        let appFrame = CGRect(x: 400, y: 0, width: 400, height: 253)

        let accessibilityFrame = transformer.accessibilityFrame(fromAppFrame: appFrame)
        let roundTrippedFrame = transformer.appFrame(fromAccessibilityFrame: accessibilityFrame)

        XCTAssertEqual(accessibilityFrame, CGRect(x: 400, y: 507, width: 400, height: 253))
        XCTAssertEqual(roundTrippedFrame, appFrame)
    }

    func testAccessibilityCoordinateTransformerRoundTripsFramesOnUpperDisplay() {
        let lowerDisplay = CGRect(x: 0, y: 0, width: 1200, height: 760)
        let upperDisplay = CGRect(x: 0, y: 760, width: 1200, height: 760)
        let transformer = AccessibilityCoordinateTransformer(screenFrames: [lowerDisplay, upperDisplay])
        let appFrame = CGRect(x: 0, y: 760, width: 600, height: 380)

        let accessibilityFrame = transformer.accessibilityFrame(fromAppFrame: appFrame)
        let roundTrippedFrame = transformer.appFrame(fromAccessibilityFrame: accessibilityFrame)

        XCTAssertEqual(accessibilityFrame, CGRect(x: 0, y: 1140, width: 600, height: 380))
        XCTAssertEqual(roundTrippedFrame, appFrame)
    }

    func testPermissionStoreRefreshUsesCheckerState() {
        let checker = StubPermissionChecker(currentStatus: .denied, requestedStatus: .granted)
        let store = AccessibilityPermissionStore(checker: checker, settingsOpener: StubSettingsOpener())

        XCTAssertEqual(store.status, .denied)

        checker.currentStatusValue = .granted
        store.refreshStatus()

        XCTAssertEqual(store.status, .granted)
    }

    func testPermissionStoreRequestPermissionUpdatesState() {
        let checker = StubPermissionChecker(currentStatus: .denied, requestedStatus: .granted)
        let store = AccessibilityPermissionStore(checker: checker, settingsOpener: StubSettingsOpener())

        store.requestPermission()

        XCTAssertEqual(checker.requestCallCount, 1)
        XCTAssertEqual(store.status, .granted)
    }

    func testFocusedWindowCommandRunnerStopsWhenPermissionIsDenied() {
        let windowController = StubFocusedWindowController()
        let runner = FocusedWindowCommandRunner(
            permissionChecker: StubPermissionChecker(currentStatus: .denied, requestedStatus: .denied),
            windowController: windowController
        )

        let result = runner.moveFocusedWindow(to: CGRect(x: 0, y: 0, width: 800, height: 600))

        XCTAssertEqual(result.failure, .permissionDenied)
        XCTAssertEqual(windowController.moveCallCount, 0)
    }

    func testFocusedWindowCommandRunnerReturnsTypedControllerErrors() {
        let windowController = StubFocusedWindowController()
        windowController.moveResult = .failure(.windowNotResizable)
        let runner = FocusedWindowCommandRunner(
            permissionChecker: StubPermissionChecker(currentStatus: .granted, requestedStatus: .granted),
            windowController: windowController
        )

        let result = runner.moveFocusedWindow(to: CGRect(x: 0, y: 0, width: 800, height: 600))

        XCTAssertEqual(result.failure, .windowNotResizable)
        XCTAssertEqual(windowController.moveCallCount, 1)
    }

    func testFocusedWindowCommandRunnerAnnotatesConstrainedFits() {
        let windowController = StubFocusedWindowController()
        windowController.moveResult = .success(
            FocusedWindowSnapshot(
                application: FocusedApplication(processID: 7, localizedName: "Terminal", bundleIdentifier: "com.apple.Terminal"),
                title: "Shell",
                frame: CGRect(x: 0, y: 0, width: 520, height: 320),
                isMovable: true,
                isResizable: true
            )
        )
        let runner = FocusedWindowCommandRunner(
            permissionChecker: StubPermissionChecker(currentStatus: .granted, requestedStatus: .granted),
            windowController: windowController
        )

        let result = runner.moveFocusedWindow(to: CGRect(x: 0, y: 0, width: 320, height: 200))

        guard case let .success(snapshot) = result else {
            return XCTFail("Expected a successful constrained-fit snapshot.")
        }

        XCTAssertEqual(snapshot.fitEvaluation?.status, .constrainedFit)
        XCTAssertEqual(snapshot.fitEvaluation?.conciseMessage, "Window did not fully fit the target frame.")
    }

    func testWindowFitEvaluatorClassifiesExactNearConstrainedAndFailedFits() {
        let evaluator = WindowFitEvaluator()
        let target = CGRect(x: 100, y: 100, width: 400, height: 300)

        let exact = evaluator.evaluate(
            intendedFrame: target,
            requestedFrame: target,
            actualFrame: CGRect(x: 100, y: 100, width: 400, height: 300)
        )
        let near = evaluator.evaluate(
            intendedFrame: target,
            requestedFrame: target,
            actualFrame: CGRect(x: 104, y: 98, width: 406, height: 296)
        )
        let constrained = evaluator.evaluate(
            intendedFrame: target,
            requestedFrame: target,
            actualFrame: CGRect(x: 100, y: 100, width: 520, height: 340)
        )
        let failed = evaluator.evaluate(
            intendedFrame: target,
            requestedFrame: target,
            actualFrame: CGRect(x: 800, y: 600, width: 400, height: 300)
        )

        XCTAssertEqual(exact.status, .exactFit)
        XCTAssertEqual(near.status, .nearFit)
        XCTAssertEqual(constrained.status, .constrainedFit)
        XCTAssertEqual(failed.status, .failedFit)
    }
}

private final class StubPermissionChecker: AccessibilityPermissionChecking {
    var currentStatusValue: AccessibilityPermissionStatus
    let requestedStatus: AccessibilityPermissionStatus
    private(set) var requestCallCount = 0

    init(currentStatus: AccessibilityPermissionStatus, requestedStatus: AccessibilityPermissionStatus) {
        self.currentStatusValue = currentStatus
        self.requestedStatus = requestedStatus
    }

    func currentStatus() -> AccessibilityPermissionStatus {
        currentStatusValue
    }

    func requestPermission() -> AccessibilityPermissionStatus {
        requestCallCount += 1
        currentStatusValue = requestedStatus
        return requestedStatus
    }
}

private struct StubSettingsOpener: AccessibilitySettingsOpening {
    @discardableResult
    func openAccessibilitySettings() -> Bool {
        true
    }
}

private final class StubFocusedWindowController: FocusedWindowControlling {
    var focusedWindowResult: Result<FocusedWindowSnapshot, AccessibilityWindowError> = .success(
        FocusedWindowSnapshot(
            application: FocusedApplication(processID: 7, localizedName: "Preview", bundleIdentifier: "com.apple.Preview"),
            title: "Document",
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            isMovable: true,
            isResizable: true
        )
    )
    var moveResult: Result<FocusedWindowSnapshot, AccessibilityWindowError> = .success(
        FocusedWindowSnapshot(
            application: FocusedApplication(processID: 7, localizedName: "Preview", bundleIdentifier: "com.apple.Preview"),
            title: "Document",
            frame: CGRect(x: 10, y: 10, width: 1024, height: 768),
            isMovable: true,
            isResizable: true
        )
    )

    private(set) var moveCallCount = 0

    func frontmostApplication() throws -> FocusedApplication {
        FocusedApplication(processID: 7, localizedName: "Preview", bundleIdentifier: "com.apple.Preview")
    }

    func focusedWindow() throws -> FocusedWindowSnapshot {
        try focusedWindowResult.get()
    }

    func moveResizeFocusedWindow(to frame: CGRect) throws -> FocusedWindowSnapshot {
        moveCallCount += 1
        return try moveResult.get()
    }
}

private extension Result where Failure == AccessibilityWindowError {
    var failure: Failure? {
        if case let .failure(error) = self {
            return error
        }

        return nil
    }
}
