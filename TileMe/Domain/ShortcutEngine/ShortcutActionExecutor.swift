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

private struct TileMoveSourceContext {
    let tileIndex: Int?
    let logicalPosition: LogicalTilePosition?
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
                    allowClampedIndex: false,
                    sourceContext: nil
                )
            case .rightHalf:
                return moveToResolvedFrame(
                    index: 1,
                    layout: BuiltinLayouts.halves,
                    display: currentDisplay(for: snapshot),
                    allowClampedIndex: false,
                    sourceContext: nil
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
        let displays = displayProvider.displays
        let currentDisplayID = currentDisplay(for: snapshot)?.id
        guard let resolution = tileTraversalService.resolution(
            for: snapshot.frame,
            direction: direction,
            currentDisplayID: currentDisplayID,
            displays: displays,
            workspaceProfile: workspaceProfile
        ) else {
            return .success(snapshot)
        }

        guard let targetDisplay = displays.first(where: { $0.id == resolution.destination.displayID }) else {
            return .failure(.noTargetDisplay)
        }

        let sourceLayout = resolvedLayout(for: resolution.source.displayID, workspaceProfile: workspaceProfile)
        let destinationLayout = resolvedLayout(for: resolution.destination.displayID, workspaceProfile: workspaceProfile)
        let targetFrame = resolution.destination.frame.clamped(to: targetDisplay.visibleFrame)

        logTileMovement(
            operation: "traversal.\(direction.rawValue)",
            display: targetDisplay,
            sourceTileIndex: resolution.source.index,
            sourceLogicalPosition: layoutEngine.logicalTilePosition(forTileIndex: resolution.source.index, in: sourceLayout),
            destinationTileIndex: resolution.destination.index,
            destinationLogicalPosition: layoutEngine.logicalTilePosition(forTileIndex: resolution.destination.index, in: destinationLayout),
            targetFrame: targetFrame
        )

        return moveWindow(to: targetFrame, within: targetDisplay.visibleFrame)
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

        let sourceLayout = resolvedLayout(for: baseDisplay.id, workspaceProfile: workspaceProfile)
        let sourceTileIndex = layoutEngine.closestTileIndex(
            to: snapshot.frame,
            in: sourceLayout,
            bounds: baseDisplay.visibleFrame
        )
        let layoutID = workspaceProfile.resolvedLayoutID(for: targetDisplay.id)
        let layout = BuiltinLayouts.definition(id: layoutID) ?? BuiltinLayouts.defaultLayout
        return moveToResolvedFrame(
            index: index,
            layout: layout,
            display: targetDisplay,
            allowClampedIndex: false,
            sourceContext: TileMoveSourceContext(
                tileIndex: sourceTileIndex,
                logicalPosition: sourceTileIndex.flatMap { layoutEngine.logicalTilePosition(forTileIndex: $0, in: sourceLayout) }
            )
        )
    }

    private func maximize(snapshot: FocusedWindowSnapshot) -> Result<FocusedWindowSnapshot, ShortcutExecutionError> {
        guard let display = currentDisplay(for: snapshot) else {
            return .failure(.noTargetDisplay)
        }

        return moveWindow(to: display.visibleFrame, within: display.visibleFrame)
    }

    private func moveToNextDisplay(snapshot: FocusedWindowSnapshot) -> Result<FocusedWindowSnapshot, ShortcutExecutionError> {
        guard let sourceDisplay = currentDisplay(for: snapshot) else {
            return .failure(.noTargetDisplay)
        }

        guard let targetDisplay = displayProvider.nextDisplay(after: sourceDisplay.id) else {
            return .failure(.noTargetDisplay)
        }

        let translatedFrame = translate(frame: snapshot.frame, from: sourceDisplay.visibleFrame, to: targetDisplay.visibleFrame)
        return moveWindow(to: translatedFrame, within: targetDisplay.visibleFrame)
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
            allowClampedIndex: true,
            sourceContext: TileMoveSourceContext(
                tileIndex: sourceTileIndex,
                logicalPosition: layoutEngine.logicalTilePosition(forTileIndex: sourceTileIndex, in: sourceLayout)
            )
        )
    }

    private func moveToResolvedFrame(
        index: Int,
        layout: LayoutDefinition,
        display: DisplayProfile?,
        allowClampedIndex: Bool,
        sourceContext: TileMoveSourceContext?
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

        let clampedTargetFrame = targetFrame.frame.clamped(to: display.visibleFrame)
        logTileMovement(
            operation: allowClampedIndex ? "tileMove.clampedIndex" : "tileMove",
            display: display,
            sourceTileIndex: sourceContext?.tileIndex,
            sourceLogicalPosition: sourceContext?.logicalPosition,
            destinationTileIndex: resolvedIndex,
            destinationLogicalPosition: layoutEngine.logicalTilePosition(forTileIndex: resolvedIndex, in: layout),
            targetFrame: clampedTargetFrame
        )
        return moveWindow(to: clampedTargetFrame, within: display.visibleFrame)
    }

    private func moveWindow(to frame: CGRect, within visibleFrame: CGRect? = nil) -> Result<FocusedWindowSnapshot, ShortcutExecutionError> {
        let targetFrame = (visibleFrame.map { frame.clamped(to: $0) } ?? frame).integral
        let finalTargetFrame = visibleFrame.map { targetFrame.clamped(to: $0) } ?? targetFrame

        switch windowCommands.moveFocusedWindow(to: finalTargetFrame) {
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

    private func resolvedLayout(for displayID: String, workspaceProfile: WorkspaceProfile) -> LayoutDefinition {
        let layoutID = workspaceProfile.resolvedLayoutID(for: displayID)
        return BuiltinLayouts.definition(id: layoutID) ?? BuiltinLayouts.defaultLayout
    }

    private func logTileMovement(
        operation: String,
        display: DisplayProfile,
        sourceTileIndex: Int?,
        sourceLogicalPosition: LogicalTilePosition?,
        destinationTileIndex: Int,
        destinationLogicalPosition: LogicalTilePosition?,
        targetFrame: CGRect
    ) {
#if DEBUG
        let sourceIndexDescription = sourceTileIndex.map(String.init) ?? "unresolved"
        let sourceRowDescription = sourceLogicalPosition.map { String($0.row) } ?? "n/a"
        let sourceColumnDescription = sourceLogicalPosition.map { String($0.column) } ?? "n/a"
        let destinationRowDescription = destinationLogicalPosition.map { String($0.row) } ?? "n/a"
        let destinationColumnDescription = destinationLogicalPosition.map { String($0.column) } ?? "n/a"

        shortcutActionLogger.debug(
            "Tile movement operation=\(operation, privacy: .public) displayID=\(display.id, privacy: .public) visibleFrame=\(display.visibleFrame.debugDescription, privacy: .public) sourceTileIndex=\(sourceIndexDescription, privacy: .public) sourceRow=\(sourceRowDescription, privacy: .public) sourceColumn=\(sourceColumnDescription, privacy: .public) destinationTileIndex=\(destinationTileIndex, privacy: .public) destinationRow=\(destinationRowDescription, privacy: .public) destinationColumn=\(destinationColumnDescription, privacy: .public) targetFrame=\(targetFrame.debugDescription, privacy: .public)"
        )
#endif
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

private extension CGRect {
    func clamped(to bounds: CGRect) -> CGRect {
        let clampedWidth = Swift.min(width, bounds.width)
        let clampedHeight = Swift.min(height, bounds.height)
        let clampedX = Swift.min(Swift.max(minX, bounds.minX), bounds.maxX - clampedWidth)
        let clampedY = Swift.min(Swift.max(minY, bounds.minY), bounds.maxY - clampedHeight)

        return CGRect(x: clampedX, y: clampedY, width: clampedWidth, height: clampedHeight)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
