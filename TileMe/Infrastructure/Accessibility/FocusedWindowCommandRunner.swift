import CoreGraphics
import Foundation
import OSLog

private let focusedWindowCommandLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "TileMe",
    category: "FocusedWindowCommands"
)

protocol FocusedWindowCommandRunning {
    func inspectFocusedWindow() -> Result<FocusedWindowSnapshot, AccessibilityWindowError>
    func moveFocusedWindow(to frame: CGRect) -> Result<FocusedWindowSnapshot, AccessibilityWindowError>
}

struct FocusedWindowCommandRunner: FocusedWindowCommandRunning {
    private let permissionChecker: any AccessibilityPermissionChecking
    private let windowController: any FocusedWindowControlling
    private let fitEvaluator: WindowFitEvaluator

    init(
        permissionChecker: any AccessibilityPermissionChecking = SystemAccessibilityPermissionChecker(),
        windowController: any FocusedWindowControlling = SystemFocusedWindowController(),
        fitEvaluator: WindowFitEvaluator = WindowFitEvaluator()
    ) {
        self.permissionChecker = permissionChecker
        self.windowController = windowController
        self.fitEvaluator = fitEvaluator
    }

    func inspectFocusedWindow() -> Result<FocusedWindowSnapshot, AccessibilityWindowError> {
        guard permissionChecker.currentStatus().isGranted else {
            focusedWindowCommandLogger.error("Focused window inspection denied because Accessibility trust is missing.")
            return .failure(.permissionDenied)
        }

        do {
            let snapshot = try windowController.focusedWindow()
            focusedWindowCommandLogger.debug(
                "Focused window lookup succeeded app=\(snapshot.application.localizedName, privacy: .public) title=\(snapshot.title ?? "Untitled", privacy: .public)"
            )
            return .success(snapshot)
        } catch let error as AccessibilityWindowError {
            focusedWindowCommandLogger.error(
                "Focused window lookup failed reason=\(error.localizedDescription, privacy: .public)"
            )
            return .failure(error)
        } catch {
            focusedWindowCommandLogger.error(
                "Focused window lookup failed reason=\(error.localizedDescription, privacy: .public)"
            )
            return .failure(.unexpected(error.localizedDescription))
        }
    }

    func moveFocusedWindow(to frame: CGRect) -> Result<FocusedWindowSnapshot, AccessibilityWindowError> {
        guard permissionChecker.currentStatus().isGranted else {
            focusedWindowCommandLogger.error("Focused window move denied because Accessibility trust is missing.")
            return .failure(.permissionDenied)
        }

        do {
            let snapshot = try windowController.moveResizeFocusedWindow(to: frame)
            let fitEvaluation = fitEvaluator.evaluate(
                intendedFrame: frame,
                requestedFrame: frame,
                actualFrame: snapshot.frame
            )
            let evaluatedSnapshot = snapshot.updatingFitEvaluation(fitEvaluation)

            if fitEvaluation.appearsConstrained {
                focusedWindowCommandLogger.notice(
                    "Focused window move completed with constrained readback \(fitEvaluation.logSummary, privacy: .public)"
                )
            } else {
                focusedWindowCommandLogger.debug(
                    "Focused window move completed \(fitEvaluation.logSummary, privacy: .public)"
                )
            }

            return .success(evaluatedSnapshot)
        } catch let error as AccessibilityWindowError {
            focusedWindowCommandLogger.error(
                "Focused window move failed frame=\(frame.debugDescription, privacy: .public) reason=\(error.localizedDescription, privacy: .public)"
            )
            return .failure(error)
        } catch {
            focusedWindowCommandLogger.error(
                "Focused window move failed frame=\(frame.debugDescription, privacy: .public) reason=\(error.localizedDescription, privacy: .public)"
            )
            return .failure(.unexpected(error.localizedDescription))
        }
    }
}
