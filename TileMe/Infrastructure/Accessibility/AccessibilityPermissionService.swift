import AppKit
@preconcurrency import ApplicationServices
import Foundation
import OSLog

private let accessibilityPermissionLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "TileMe",
    category: "AccessibilityPermission"
)

enum AccessibilityPermissionStatus: String, Equatable, Sendable {
    case granted
    case denied

    var isGranted: Bool {
        self == .granted
    }

    var title: String {
        switch self {
        case .granted:
            return "Accessibility Access Ready"
        case .denied:
            return "Accessibility Access Needed"
        }
    }

    var detail: String {
        switch self {
        case .granted:
            return "Tile Me can inspect the focused window and apply move or resize actions only when you trigger a shortcut or menu command."
        case .denied:
            return "macOS requires Accessibility access before Tile Me can inspect or move another app's windows."
        }
    }

    var symbolName: String {
        switch self {
        case .granted:
            return "checkmark.shield"
        case .denied:
            return "hand.raised"
        }
    }
}

protocol AccessibilityPermissionChecking {
    func currentStatus() -> AccessibilityPermissionStatus
    func requestPermission() -> AccessibilityPermissionStatus
}

protocol AccessibilitySettingsOpening {
    @discardableResult
    func openAccessibilitySettings() -> Bool
}

struct SystemAccessibilityPermissionChecker: AccessibilityPermissionChecking {
    func currentStatus() -> AccessibilityPermissionStatus {
        let isTrusted = AXIsProcessTrustedWithOptions(trustOptions(prompt: false))
        let status: AccessibilityPermissionStatus = isTrusted ? .granted : .denied
        accessibilityPermissionLogger.debug(
            "Trust check bundleID=\(runtimeBundleIdentifier, privacy: .public) trusted=\(isTrusted, privacy: .public)"
        )
        return status
    }

    func requestPermission() -> AccessibilityPermissionStatus {
        let isTrusted = AXIsProcessTrustedWithOptions(trustOptions(prompt: true))
        let status: AccessibilityPermissionStatus = isTrusted ? .granted : .denied
        accessibilityPermissionLogger.notice(
            "Requested trust prompt bundleID=\(runtimeBundleIdentifier, privacy: .public) trusted=\(isTrusted, privacy: .public)"
        )
        return status
    }

    private func trustOptions(prompt: Bool) -> CFDictionary {
        [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
    }

    private var runtimeBundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "unknown.bundle"
    }
}

struct AccessibilitySettingsOpener: AccessibilitySettingsOpening {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    @discardableResult
    func openAccessibilitySettings() -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return false
        }

        return workspace.open(url)
    }
}

@MainActor
final class AccessibilityPermissionStore: ObservableObject {
    @Published private(set) var status: AccessibilityPermissionStatus

    private let checker: any AccessibilityPermissionChecking
    private let settingsOpener: any AccessibilitySettingsOpening

    init(
        checker: any AccessibilityPermissionChecking = SystemAccessibilityPermissionChecker(),
        settingsOpener: any AccessibilitySettingsOpening = AccessibilitySettingsOpener()
    ) {
        self.checker = checker
        self.settingsOpener = settingsOpener
        self.status = checker.currentStatus()
    }

    func refreshStatus() {
        status = checker.currentStatus()
    }

    func requestPermission() {
        status = checker.requestPermission()
    }

    @discardableResult
    func openAccessibilitySettings() -> Bool {
        settingsOpener.openAccessibilitySettings()
    }
}

#if DEBUG
extension AccessibilityPermissionStore {
    var diagnosticBundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "Unavailable"
    }

    var diagnosticExecutablePath: String {
        Bundle.main.executableURL?.path ?? CommandLine.arguments.first ?? "Unavailable"
    }
}
#endif
