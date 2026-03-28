import AppKit
import Combine
import CoreGraphics
import Foundation

protocol DisplayDiscovering {
    func discoverDisplays() -> [DisplayProfile]
}

struct SystemDisplayDiscovery: DisplayDiscovering {
    func discoverDisplays() -> [DisplayProfile] {
        NSScreen.screens.compactMap(\.tileMeProfile)
    }
}

@MainActor
final class DisplayManager: NSObject, ObservableObject {
    @Published private(set) var displays: [DisplayProfile] = []

    private let notificationCenter: NotificationCenter
    private let displayDiscovery: any DisplayDiscovering

    init(
        notificationCenter: NotificationCenter = .default,
        displayDiscovery: any DisplayDiscovering = SystemDisplayDiscovery()
    ) {
        self.notificationCenter = notificationCenter
        self.displayDiscovery = displayDiscovery
        super.init()
        refreshDisplays()

        notificationCenter.addObserver(
            self,
            selector: #selector(handleScreenParametersChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    func refreshDisplays() {
        let profiles = displayDiscovery.discoverDisplays()
        displays = Self.sortDisplays(profiles)
    }

    func display(withID id: String?) -> DisplayProfile? {
        guard let id else {
            return nil
        }

        return displays.first { $0.id == id }
    }

    func display(containing frame: CGRect) -> DisplayProfile? {
        let midpoint = CGPoint(x: frame.midX, y: frame.midY)
        if let exactMatch = displays.first(where: { $0.frame.contains(midpoint) }) {
            return exactMatch
        }

        return displays.max { lhs, rhs in
            lhs.frame.intersection(frame).area < rhs.frame.intersection(frame).area
        }
    }

    func nextDisplay(after displayID: String?) -> DisplayProfile? {
        guard !displays.isEmpty else {
            return nil
        }

        guard let displayID, let currentIndex = displays.firstIndex(where: { $0.id == displayID }) else {
            return displays.first
        }

        let nextIndex = displays.index(after: currentIndex)
        return nextIndex < displays.endIndex ? displays[nextIndex] : displays.first
    }

    func otherDisplays(excluding displayID: String) -> [DisplayProfile] {
        displays.filter { $0.id != displayID }
    }

    static func sortDisplays(_ displays: [DisplayProfile]) -> [DisplayProfile] {
        displays.sorted { lhs, rhs in
            if lhs.frame.minX != rhs.frame.minX {
                return lhs.frame.minX < rhs.frame.minX
            }

            if lhs.frame.maxY != rhs.frame.maxY {
                return lhs.frame.maxY > rhs.frame.maxY
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    @objc
    private func handleScreenParametersChange(_ notification: Notification) {
        refreshDisplays()
    }
}

private extension NSScreen {
    var tileMeProfile: DisplayProfile? {
        guard let displayNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        let displayID = CGDirectDisplayID(displayNumber.uint32Value)
        return DisplayProfile(
            id: String(displayID),
            name: localizedName,
            frame: frame,
            visibleFrame: visibleFrame,
            scale: backingScaleFactor,
            isBuiltIn: CGDisplayIsBuiltin(displayID) != 0
        )
    }
}

private extension CGRect {
    var area: CGFloat {
        width * height
    }
}
