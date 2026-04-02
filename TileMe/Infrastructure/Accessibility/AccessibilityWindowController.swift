import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import OSLog

private let accessibilityWindowLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "TileMe",
    category: "AccessibilityWindow"
)

struct AccessibilityCoordinateTransformer: Sendable {
    let screenFrames: [CGRect]

    func appFrame(fromAccessibilityFrame frame: CGRect) -> CGRect {
        reflectedFrame(from: frame)
    }

    func accessibilityFrame(fromAppFrame frame: CGRect) -> CGRect {
        reflectedFrame(from: frame)
    }

    private func reflectedFrame(from frame: CGRect) -> CGRect {
        // AXPosition uses a global top-left origin anchored to the menu bar screen.
        guard let accessibilityGlobalTop = accessibilityGlobalTop else {
            return frame
        }

        return CGRect(
            x: frame.minX,
            y: accessibilityGlobalTop - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    private var accessibilityGlobalTop: CGFloat? {
        screenFrames.first(where: { $0.contains(CGPoint.zero) })?.maxY
            ?? screenFrames.first?.maxY
    }
}

struct FocusedApplication: Equatable, Sendable {
    let processID: pid_t
    let localizedName: String
    let bundleIdentifier: String?
}

struct FocusedWindowSnapshot: Equatable, Sendable {
    let application: FocusedApplication
    let title: String?
    let frame: CGRect
    let isMovable: Bool
    let isResizable: Bool
    let fitEvaluation: WindowFitEvaluation?

    init(
        application: FocusedApplication,
        title: String?,
        frame: CGRect,
        isMovable: Bool,
        isResizable: Bool,
        fitEvaluation: WindowFitEvaluation? = nil
    ) {
        self.application = application
        self.title = title
        self.frame = frame
        self.isMovable = isMovable
        self.isResizable = isResizable
        self.fitEvaluation = fitEvaluation
    }

    func updatingFitEvaluation(_ fitEvaluation: WindowFitEvaluation?) -> FocusedWindowSnapshot {
        FocusedWindowSnapshot(
            application: application,
            title: title,
            frame: frame,
            isMovable: isMovable,
            isResizable: isResizable,
            fitEvaluation: fitEvaluation
        )
    }
}

enum AccessibilityWindowError: LocalizedError, Equatable {
    case permissionDenied
    case noFrontmostApplication
    case noFocusedWindow
    case invalidTargetFrame
    case attributeUnavailable(String)
    case unsupportedAttributeValue(String)
    case windowNotMovable
    case windowNotResizable
    case apiFailure(operation: String, code: Int32)
    case unexpected(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Accessibility permission is not enabled."
        case .noFrontmostApplication:
            return "No frontmost application is available."
        case .noFocusedWindow:
            return "The frontmost application does not expose a focused window."
        case .invalidTargetFrame:
            return "The requested target frame is invalid."
        case let .attributeUnavailable(attribute):
            return "The window attribute \(attribute) is unavailable."
        case let .unsupportedAttributeValue(attribute):
            return "The window attribute \(attribute) is not available in a supported format."
        case .windowNotMovable:
            return "The focused window cannot be moved."
        case .windowNotResizable:
            return "The focused window cannot be resized."
        case let .apiFailure(operation, code):
            return "\(operation) failed with accessibility error \(code)."
        case let .unexpected(message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Enable Tile Me in System Settings > Privacy & Security > Accessibility, then refresh the permission status."
        case .windowNotMovable, .windowNotResizable:
            return "Try a standard app window. Some panels, sheets, or system-managed windows cannot be tiled."
        default:
            return nil
        }
    }
}

protocol FocusedWindowControlling {
    func frontmostApplication() throws -> FocusedApplication
    func focusedWindow() throws -> FocusedWindowSnapshot

    @discardableResult
    func moveResizeFocusedWindow(to frame: CGRect) throws -> FocusedWindowSnapshot
}

final class SystemFocusedWindowController: FocusedWindowControlling {
    private let workspace: NSWorkspace
    private let permissionChecker: any AccessibilityPermissionChecking
    private let screenFramesProvider: @Sendable () -> [CGRect]

    init(
        workspace: NSWorkspace = .shared,
        permissionChecker: any AccessibilityPermissionChecking = SystemAccessibilityPermissionChecker(),
        screenFramesProvider: @escaping @Sendable () -> [CGRect] = { NSScreen.screens.map(\.frame) }
    ) {
        self.workspace = workspace
        self.permissionChecker = permissionChecker
        self.screenFramesProvider = screenFramesProvider
    }

    func frontmostApplication() throws -> FocusedApplication {
        guard let application = workspace.frontmostApplication else {
            accessibilityWindowLogger.error("Frontmost application lookup failed because no frontmost application was available.")
            throw AccessibilityWindowError.noFrontmostApplication
        }

        let focusedApplication = FocusedApplication(
            processID: application.processIdentifier,
            localizedName: application.localizedName ?? application.bundleIdentifier ?? "Unknown App",
            bundleIdentifier: application.bundleIdentifier
        )
        accessibilityWindowLogger.debug(
            "Frontmost application name=\(focusedApplication.localizedName, privacy: .public) bundleID=\(focusedApplication.bundleIdentifier ?? "Unavailable", privacy: .public) pid=\(focusedApplication.processID, privacy: .public)"
        )
        return focusedApplication
    }

    func focusedWindow() throws -> FocusedWindowSnapshot {
        try requirePermission()
        let application = try frontmostApplication()
        let windowElement = try focusedWindowElement(for: application.processID)
        let snapshot = try snapshot(for: windowElement, application: application)
        accessibilityWindowLogger.debug(
            "Focused window frame=\(snapshot.frame.debugDescription, privacy: .public) movable=\(snapshot.isMovable, privacy: .public) resizable=\(snapshot.isResizable, privacy: .public)"
        )
        return snapshot
    }

    @discardableResult
    func moveResizeFocusedWindow(to frame: CGRect) throws -> FocusedWindowSnapshot {
        try requirePermission()

        guard frame.width > 0, frame.height > 0 else {
            throw AccessibilityWindowError.invalidTargetFrame
        }

        let application = try frontmostApplication()
        let windowElement = try focusedWindowElement(for: application.processID)

        guard isAttributeSettable(kAXPositionAttribute as CFString, on: windowElement) else {
            throw AccessibilityWindowError.windowNotMovable
        }

        guard isAttributeSettable(kAXSizeAttribute as CFString, on: windowElement) else {
            throw AccessibilityWindowError.windowNotResizable
        }

        let accessibilityFrame = coordinateTransformer.accessibilityFrame(fromAppFrame: frame)
        try set(size: accessibilityFrame.size, for: windowElement)
        try set(position: accessibilityFrame.origin, for: windowElement)

        let snapshot = try snapshot(for: windowElement, application: application)
        accessibilityWindowLogger.debug(
            "Move/resize requestedFrame=\(frame.debugDescription, privacy: .public) axFrame=\(accessibilityFrame.debugDescription, privacy: .public) appliedFrame=\(snapshot.frame.debugDescription, privacy: .public)"
        )
        return snapshot
    }

    private func requirePermission() throws {
        guard permissionChecker.currentStatus().isGranted else {
            accessibilityWindowLogger.error("Accessibility trust check failed inside window controller.")
            throw AccessibilityWindowError.permissionDenied
        }
    }

    private func focusedWindowElement(for processID: pid_t) throws -> AXUIElement {
        let applicationElement = AXUIElementCreateApplication(processID)
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(applicationElement, kAXFocusedWindowAttribute as CFString, &value)

        switch error {
        case .success:
            break
        case .noValue:
            accessibilityWindowLogger.error("Focused window lookup returned no value for pid=\(processID, privacy: .public).")
            throw AccessibilityWindowError.noFocusedWindow
        default:
            accessibilityWindowLogger.error(
                "Focused window lookup failed for pid=\(processID, privacy: .public) code=\(error.rawValue, privacy: .public)"
            )
            throw AccessibilityWindowError.apiFailure(operation: "Read focused window", code: error.rawValue)
        }

        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            accessibilityWindowLogger.error("Focused window lookup returned an unsupported AX value.")
            throw AccessibilityWindowError.unsupportedAttributeValue(kAXFocusedWindowAttribute as String)
        }

        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func snapshot(for windowElement: AXUIElement, application: FocusedApplication) throws -> FocusedWindowSnapshot {
        let position = try pointAttribute(kAXPositionAttribute as CFString, on: windowElement)
        let size = try sizeAttribute(kAXSizeAttribute as CFString, on: windowElement)
        let title = stringAttribute(kAXTitleAttribute as CFString, on: windowElement)
        let accessibilityFrame = CGRect(origin: position, size: size)
        let normalizedFrame = coordinateTransformer.appFrame(fromAccessibilityFrame: accessibilityFrame)

        accessibilityWindowLogger.debug(
            "Window snapshot rawAXFrame=\(accessibilityFrame.debugDescription, privacy: .public) normalizedFrame=\(normalizedFrame.debugDescription, privacy: .public)"
        )

        return FocusedWindowSnapshot(
            application: application,
            title: title,
            frame: normalizedFrame,
            isMovable: isAttributeSettable(kAXPositionAttribute as CFString, on: windowElement),
            isResizable: isAttributeSettable(kAXSizeAttribute as CFString, on: windowElement)
        )
    }

    private var coordinateTransformer: AccessibilityCoordinateTransformer {
        AccessibilityCoordinateTransformer(screenFrames: screenFramesProvider())
    }

    private func stringAttribute(_ attribute: CFString, on element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard error == .success else {
            return nil
        }

        return value as? String
    }

    private func pointAttribute(_ attribute: CFString, on element: AXUIElement) throws -> CGPoint {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard error == .success else {
            throw readError(for: attribute, code: error)
        }

        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else {
            throw AccessibilityWindowError.unsupportedAttributeValue(attribute as String)
        }

        let axValue = unsafeDowncast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgPoint else {
            throw AccessibilityWindowError.unsupportedAttributeValue(attribute as String)
        }

        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else {
            throw AccessibilityWindowError.unsupportedAttributeValue(attribute as String)
        }

        return point
    }

    private func sizeAttribute(_ attribute: CFString, on element: AXUIElement) throws -> CGSize {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard error == .success else {
            throw readError(for: attribute, code: error)
        }

        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else {
            throw AccessibilityWindowError.unsupportedAttributeValue(attribute as String)
        }

        let axValue = unsafeDowncast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgSize else {
            throw AccessibilityWindowError.unsupportedAttributeValue(attribute as String)
        }

        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else {
            throw AccessibilityWindowError.unsupportedAttributeValue(attribute as String)
        }

        return size
    }

    private func set(position: CGPoint, for element: AXUIElement) throws {
        var position = position
        guard let value = AXValueCreate(.cgPoint, &position) else {
            throw AccessibilityWindowError.unsupportedAttributeValue(kAXPositionAttribute as String)
        }

        let error = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
        guard error == .success else {
            throw AccessibilityWindowError.apiFailure(operation: "Set window position", code: error.rawValue)
        }
    }

    private func set(size: CGSize, for element: AXUIElement) throws {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else {
            throw AccessibilityWindowError.unsupportedAttributeValue(kAXSizeAttribute as String)
        }

        let error = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
        guard error == .success else {
            throw AccessibilityWindowError.apiFailure(operation: "Set window size", code: error.rawValue)
        }
    }

    private func isAttributeSettable(_ attribute: CFString, on element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(element, attribute, &settable)
        return error == .success && settable.boolValue
    }

    private func readError(for attribute: CFString, code: AXError) -> AccessibilityWindowError {
        accessibilityWindowLogger.error(
            "Attribute read failed attribute=\(attribute as String, privacy: .public) code=\(code.rawValue, privacy: .public)"
        )
        switch code {
        case .noValue:
            return .attributeUnavailable(attribute as String)
        default:
            return .apiFailure(operation: "Read \(attribute as String)", code: code.rawValue)
        }
    }
}

private extension CGRect {
    var area: CGFloat {
        width * height
    }
}
