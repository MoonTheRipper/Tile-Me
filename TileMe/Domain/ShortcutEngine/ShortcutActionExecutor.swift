import CoreGraphics
import Foundation
import OSLog

private let shortcutActionLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "TileMe",
    category: "ShortcutActions"
)

@MainActor
protocol DisplayProviding {
    var displays: [DisplayProfile] { get }

    func display(containing frame: CGRect) -> DisplayProfile?
    func nextDisplay(after displayID: String?) -> DisplayProfile?
}

extension DisplayManager: DisplayProviding {}

enum ShortcutCommand: Hashable, Sendable {
    case action(ShortcutAction)
    case moveToTileOnNextDisplay(index: Int)

    var id: String {
        switch self {
        case let .action(action):
            return action.id
        case let .moveToTileOnNextDisplay(index):
            return "tile.\(index).nextDisplay"
        }
    }
}

enum ShortcutExecutionError: LocalizedError, Equatable {
    case noDisplays
    case noTargetDisplay
    case tileUnavailable(index: Int)
    case accessibility(AccessibilityWindowError)

    var errorDescription: String? {
        switch self {
        case .noDisplays:
            return "No displays are currently available."
        case .noTargetDisplay:
            return "Tile Me could not resolve a target display for the shortcut."
        case let .tileUnavailable(index):
            return "The current layout does not expose tile \(index + 1)."
        case let .accessibility(error):
            return error.errorDescription
        }
    }
}

protocol ShortcutActionExecuting {
    @MainActor
    func execute(_ command: ShortcutCommand, workspaceProfile: WorkspaceProfile) -> Result<FocusedWindowSnapshot, ShortcutExecutionError>
}

@MainActor
final class ShortcutActionExecutor: ShortcutActionExecuting {
    private let displayProvider: any DisplayProviding
    private let windowCommands: any FocusedWindowCommandRunning
    private let layoutEngine: LayoutEngine
    private let tileTraversalService: TileTraversalService

    init(
        displayProvider: any DisplayProviding,
        windowCommands: any FocusedWindowCommandRunning = FocusedWindowCommandRunner(),
        layoutEngine: LayoutEngine = LayoutEngine(),
        tileTraversalService: TileTraversalService = TileTraversalService()
    ) {
        self.displayProvider = displayProvider
        self.windowCommands = windowCommands
        self.layoutEngine = layoutEngine
        self.tileTraversalService = tileTraversalService
    }

    func execute(_ command: ShortcutCommand, workspaceProfile: WorkspaceProfile) -> Result<FocusedWindowSnapshot, ShortcutExecutionError> {
        switch windowCommands.inspectFocusedWindow() {
        case let .failure(error):
            return .failure(.accessibility(error))
        case let .success(snapshot):
            return execute(command, snapshot: snapshot, workspaceProfile: workspaceProfile)
        }
    }

    private func execute(
        _ command: ShortcutCommand,
        snapshot: FocusedWindowSnapshot,
        workspaceProfile: WorkspaceProfile
    ) -> Result<FocusedWindowSnapshot, ShortcutExecutionError> {
        switch command {
        case let .action(action):
            switch action {
            case let .moveToTile(index):
                return moveToTile(index: index, onNextDisplay: false, snapshot: snapshot, workspaceProfile: workspaceProfile)
            case let .traverse(direction):
                return traverse(direction: direction, snapshot: snapshot, workspaceProfile: workspaceProfile)
            case .maximize:
                return maximize(snapshot: snapshot)
            case .moveToNextDisplay:
                return moveToNextDisplay(snapshot: snapshot)
            case .moveToNextDisplayPreservingTile:
                return moveToNextDisplayPreservingTile(snapshot: snapshot, workspaceProfile: workspaceProfile)
            case .leftHalf:
                return moveToResolvedFrame(
                    index: 0,
                    layout: BuiltinLayouts.halves,
                    display: currentDisplay(for: snapshot),
                    allowClampedIndex: false
                )
            case .rightHalf:
                return moveToResolvedFrame(
                    index: 1,
                    layout: BuiltinLayouts.halves,
                    display: currentDisplay(for: snapshot),
                    allowClampedIndex: false
                )
            }
        case let .moveToTileOnNextDisplay(index):
            return moveToTile(index: index, onNextDisplay: true, snapshot: snapshot, workspaceProfile: workspaceProfile)
        }
    }

    private func traverse(
        direction: TileTraversalDirection,
        snapshot: FocusedWindowSnapshot,
        workspaceProfile: WorkspaceProfile
    ) -> Result<FocusedWindowSnapshot, ShortcutExecutionError> {
        let currentDisplayID = currentDisplay(for: snapshot)?.id
        guard let destination = tileTraversalService.destination(
            for: snapshot.frame,
            direction: direction,
            currentDisplayID: currentDisplayID,
            displays: displayProvider.displays,
            workspaceProfile: workspaceProfile
        ) else {
            return .success(snapshot)
        }

        shortcutActionLogger.debug(
            "Traversal selected direction=\(direction.rawValue, privacy: .public) tileID=\(destination.tileID, privacy: .public) displayID=\(destination.displayID, privacy: .public) target=\(destination.frame.debugDescription, privacy: .public)"
        )
        return moveWindow(to: destination.frame)
    }

    private func moveToTile(
        index: Int,
        onNextDisplay: Bool,
        snapshot: FocusedWindowSnapshot,
        workspaceProfile: WorkspaceProfile
    ) -> Result<FocusedWindowSnapshot, ShortcutExecutionError> {
        guard let baseDisplay = currentDisplay(for: snapshot) else {
            return .failure(.noTargetDisplay)
        }

        let targetDisplay = onNextDisplay ? displayProvider.nextDisplay(after: baseDisplay.id) : baseDisplay
        guard let targetDisplay else {
            return .failure(.noTargetDisplay)
        }

        let layoutID = workspaceProfile.resolvedLayoutID(for: targetDisplay.id)
        let layout = BuiltinLayouts.definition(id: layoutID) ?? BuiltinLayouts.defaultLayout
        return moveToResolvedFrame(index: index, layout: layout, display: targetDisplay, allowClampedIndex: false)
    }

    private func maximize(snapshot: FocusedWindowSnapshot) -> Result<FocusedWindowSnapshot, ShortcutExecutionError> {
        guard let display = currentDisplay(for: snapshot) else {
            return .failure(.noTargetDisplay)
        }

        return moveWindow(to: display.visibleFrame)
    }

    private func moveToNextDisplay(snapshot: FocusedWindowSnapshot) -> Result<FocusedWindowSnapshot, ShortcutExecutionError> {
        guard let sourceDisplay = currentDisplay(for: snapshot) else {
            return .failure(.noTargetDisplay)
        }

        guard let targetDisplay = displayProvider.nextDisplay(after: sourceDisplay.id) else {
            return .failure(.noTargetDisplay)
        }

        let translatedFrame = translate(frame: snapshot.frame, from: sourceDisplay.visibleFrame, to: targetDisplay.visibleFrame)
        return moveWindow(to: translatedFrame)
    }

    private func moveToNextDisplayPreservingTile(
        snapshot: FocusedWindowSnapshot,
        workspaceProfile: WorkspaceProfile
    ) -> Result<FocusedWindowSnapshot, ShortcutExecutionError> {
        guard let sourceDisplay = currentDisplay(for: snapshot) else {
            return .failure(.noTargetDisplay)
        }

        guard let targetDisplay = displayProvider.nextDisplay(after: sourceDisplay.id) else {
            return .failure(.noTargetDisplay)
        }

        let sourceLayoutID = workspaceProfile.resolvedLayoutID(for: sourceDisplay.id)
        let sourceLayout = BuiltinLayouts.definition(id: sourceLayoutID) ?? BuiltinLayouts.defaultLayout
        let sourceTileIndex = layoutEngine.closestTileIndex(
            to: snapshot.frame,
            in: sourceLayout,
            bounds: sourceDisplay.visibleFrame
        ) ?? 0

        let targetLayoutID = workspaceProfile.resolvedLayoutID(for: targetDisplay.id)
        let targetLayout = BuiltinLayouts.definition(id: targetLayoutID) ?? BuiltinLayouts.defaultLayout
        return moveToResolvedFrame(
            index: sourceTileIndex,
            layout: targetLayout,
            display: targetDisplay,
            allowClampedIndex: true
        )
    }

    private func moveToResolvedFrame(
        index: Int,
        layout: LayoutDefinition,
        display: DisplayProfile?,
        allowClampedIndex: Bool
    ) -> Result<FocusedWindowSnapshot, ShortcutExecutionError> {
        guard let display else {
            return .failure(.noTargetDisplay)
        }

        let frames = layoutEngine.resolve(layout: layout, in: display.visibleFrame)
        guard !frames.isEmpty else {
            return .failure(.tileUnavailable(index: index))
        }

        let resolvedIndex = allowClampedIndex ? min(index, frames.count - 1) : index
        guard let targetFrame = frames.first(where: { $0.index == resolvedIndex }) else {
            return .failure(.tileUnavailable(index: index))
        }

        shortcutActionLogger.debug(
            "Tile move selected index=\(resolvedIndex, privacy: .public) tileID=\(targetFrame.tileID, privacy: .public) displayID=\(display.id, privacy: .public) target=\(targetFrame.frame.debugDescription, privacy: .public)"
        )
        return moveWindow(to: targetFrame.frame)
    }

    private func moveWindow(to frame: CGRect) -> Result<FocusedWindowSnapshot, ShortcutExecutionError> {
        switch windowCommands.moveFocusedWindow(to: frame.integral) {
        case let .success(snapshot):
            return .success(snapshot)
        case let .failure(error):
            return .failure(.accessibility(error))
        }
    }

    private func currentDisplay(for snapshot: FocusedWindowSnapshot) -> DisplayProfile? {
        if let display = displayProvider.display(containing: snapshot.frame) {
            return display
        }

        return displayProvider.displays.first
    }

    private func translate(frame: CGRect, from sourceBounds: CGRect, to targetBounds: CGRect) -> CGRect {
        let clampedWidth = min(frame.width, targetBounds.width)
        let clampedHeight = min(frame.height, targetBounds.height)
        let targetSize = CGSize(width: clampedWidth, height: clampedHeight)
        let sourceUsableWidth = max(sourceBounds.width - frame.width, 0)
        let sourceUsableHeight = max(sourceBounds.height - frame.height, 0)

        let xRatio = sourceUsableWidth > 0
            ? ((frame.minX - sourceBounds.minX).clamped(to: 0...sourceUsableWidth) / sourceUsableWidth)
            : 0.5
        let yRatio = sourceUsableHeight > 0
            ? ((frame.minY - sourceBounds.minY).clamped(to: 0...sourceUsableHeight) / sourceUsableHeight)
            : 0.5

        let targetUsableWidth = max(targetBounds.width - targetSize.width, 0)
        let targetUsableHeight = max(targetBounds.height - targetSize.height, 0)

        return CGRect(
            x: targetBounds.minX + (targetUsableWidth * xRatio),
            y: targetBounds.minY + (targetUsableHeight * yRatio),
            width: targetSize.width,
            height: targetSize.height
        ).integral
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
