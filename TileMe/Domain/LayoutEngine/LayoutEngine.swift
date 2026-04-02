import CoreGraphics
import Foundation

struct LogicalTilePosition: Equatable, Sendable {
    let row: Int
    let column: Int
    let totalRows: Int
    let totalColumns: Int

    var appKitRow: Int {
        totalRows - 1 - row
    }
}

struct LayoutEngine {
    func resolve(layout: LayoutDefinition, in bounds: CGRect) -> [TileFrame] {
        if let gridDescriptor = uniformGridDescriptor(for: layout) {
            return resolveUniformGrid(gridDescriptor, in: bounds)
        }

        var frames: [TileFrame] = []
        var nextIndex = 0
        appendFrames(for: layout.root, in: bounds, frames: &frames, nextIndex: &nextIndex)
        return frames
    }

    func tileFrame(at index: Int, in layout: LayoutDefinition, bounds: CGRect) -> TileFrame? {
        resolve(layout: layout, in: bounds).first { $0.index == index }
    }

    func closestTileIndex(to frame: CGRect, in layout: LayoutDefinition, bounds: CGRect) -> Int? {
        let target = CGPoint(x: frame.midX, y: frame.midY)
        return resolve(layout: layout, in: bounds)
            .min { lhs, rhs in
                lhs.frame.center.distanceSquared(to: target) < rhs.frame.center.distanceSquared(to: target)
            }?
            .index
    }

    func logicalTilePosition(forTileIndex index: Int, in layout: LayoutDefinition) -> LogicalTilePosition? {
        guard
            let gridDescriptor = uniformGridDescriptor(for: layout),
            index >= 0,
            index < (gridDescriptor.totalRows * gridDescriptor.totalColumns)
        else {
            return nil
        }

        return LogicalTilePosition(
            row: index / gridDescriptor.totalColumns,
            column: index % gridDescriptor.totalColumns,
            totalRows: gridDescriptor.totalRows,
            totalColumns: gridDescriptor.totalColumns
        )
    }

    private func appendFrames(
        for node: TileNode,
        in bounds: CGRect,
        frames: inout [TileFrame],
        nextIndex: inout Int
    ) {
        switch node {
        case let .leaf(id):
            frames.append(TileFrame(tileID: id, index: nextIndex, frame: bounds.integral))
            nextIndex += 1
        case let .split(_, axis, children):
            let childFrames = partition(bounds: bounds, axis: axis, children: children)
            for (child, childBounds) in zip(children, childFrames) {
                appendFrames(for: child.node, in: childBounds, frames: &frames, nextIndex: &nextIndex)
            }
        }
    }

    private func resolveUniformGrid(_ descriptor: UniformGridDescriptor, in visibleFrame: CGRect) -> [TileFrame] {
        var frames: [TileFrame] = []
        frames.reserveCapacity(descriptor.totalRows * descriptor.totalColumns)

        for row in 0..<descriptor.totalRows {
            for column in 0..<descriptor.totalColumns {
                let logicalPosition = LogicalTilePosition(
                    row: row,
                    column: column,
                    totalRows: descriptor.totalRows,
                    totalColumns: descriptor.totalColumns
                )
                frames.append(
                    TileFrame(
                        tileID: descriptor.tileID(row: row, column: column),
                        index: frames.count,
                        frame: logicalTileFrame(for: logicalPosition, in: visibleFrame)
                    )
                )
            }
        }

        return frames
    }

    private func logicalTileFrame(for logicalPosition: LogicalTilePosition, in visibleFrame: CGRect) -> CGRect {
        let columnWidths = segmentLengths(totalLength: visibleFrame.width, count: logicalPosition.totalColumns)
        let rowHeights = segmentLengths(totalLength: visibleFrame.height, count: logicalPosition.totalRows)
        let x = visibleFrame.minX + columnWidths.prefix(logicalPosition.column).reduce(0, +)
        let width = columnWidths[logicalPosition.column]
        let maxY = visibleFrame.maxY - rowHeights.prefix(logicalPosition.row).reduce(0, +)
        let height = rowHeights[logicalPosition.row]
        let y = maxY - height

        return CGRect(x: x, y: y, width: width, height: height)
            .integral
            .clamped(to: visibleFrame)
    }

    private func segmentLengths(totalLength: CGFloat, count: Int) -> [CGFloat] {
        guard count > 0 else {
            return []
        }

        let baseLength = count == 1 ? totalLength : (totalLength / CGFloat(count)).rounded(.towardZero)
        var remainingLength = totalLength
        return (0..<count).map { index in
            let segmentLength = index == (count - 1) ? remainingLength : baseLength
            remainingLength -= segmentLength
            return segmentLength
        }
    }

    private func uniformGridDescriptor(for layout: LayoutDefinition) -> UniformGridDescriptor? {
        guard case let .split(_, .horizontal, rowChildren) = layout.root, !rowChildren.isEmpty else {
            return nil
        }

        guard rowChildren.map(\.fraction).areApproximatelyUniform else {
            return nil
        }

        var tileIDsByRow: [[String]] = []
        var expectedColumnCount: Int?

        for rowChild in rowChildren {
            guard case let .split(_, .vertical, columnChildren) = rowChild.node, !columnChildren.isEmpty else {
                return nil
            }

            guard columnChildren.map(\.fraction).areApproximatelyUniform else {
                return nil
            }

            let leafIDs = columnChildren.compactMap { child -> String? in
                guard case let .leaf(id) = child.node else {
                    return nil
                }

                return id
            }

            guard leafIDs.count == columnChildren.count else {
                return nil
            }

            if let expectedColumnCount {
                guard leafIDs.count == expectedColumnCount else {
                    return nil
                }
            } else {
                expectedColumnCount = leafIDs.count
            }

            tileIDsByRow.append(leafIDs)
        }

        return UniformGridDescriptor(tileIDsByRow: tileIDsByRow)
    }

    private func partition(bounds: CGRect, axis: SplitAxis, children: [TileChild]) -> [CGRect] {
        guard !children.isEmpty else {
            return []
        }

        let totalWeight = children
            .map { max($0.fraction, 0) }
            .reduce(0, +)
        let fallbackWeight = totalWeight > 0 ? totalWeight : Double(children.count)
        let normalizedWeights = children.map { child in
            let weight = totalWeight > 0 ? max(child.fraction, 0) : 1
            return weight / fallbackWeight
        }

        switch axis {
        case .vertical:
            var x = bounds.minX
            return normalizedWeights.enumerated().map { index, weight in
                let width = index == children.indices.last
                    ? bounds.maxX - x
                    : (bounds.width * weight).rounded(.towardZero)
                defer { x += width }
                return CGRect(x: x, y: bounds.minY, width: width, height: bounds.height)
            }
        case .horizontal:
            var currentMaxY = bounds.maxY
            return normalizedWeights.enumerated().map { index, weight in
                let height = index == children.indices.last
                    ? currentMaxY - bounds.minY
                    : (bounds.height * weight).rounded(.towardZero)
                let rect = CGRect(x: bounds.minX, y: currentMaxY - height, width: bounds.width, height: height)
                currentMaxY -= height
                return rect
            }
        }
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    func clamped(to bounds: CGRect) -> CGRect {
        let clampedWidth = Swift.min(width, bounds.width)
        let clampedHeight = Swift.min(height, bounds.height)
        let clampedX = Swift.min(Swift.max(minX, bounds.minX), bounds.maxX - clampedWidth)
        let clampedY = Swift.min(Swift.max(minY, bounds.minY), bounds.maxY - clampedHeight)

        return CGRect(x: clampedX, y: clampedY, width: clampedWidth, height: clampedHeight)
    }
}

private extension CGPoint {
    func distanceSquared(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return (dx * dx) + (dy * dy)
    }
}

private struct UniformGridDescriptor {
    let tileIDsByRow: [[String]]

    var totalRows: Int {
        tileIDsByRow.count
    }

    var totalColumns: Int {
        tileIDsByRow.first?.count ?? 0
    }

    func tileID(row: Int, column: Int) -> String {
        tileIDsByRow[row][column]
    }
}

private extension Array where Element == Double {
    var areApproximatelyUniform: Bool {
        guard let first else {
            return false
        }

        return allSatisfy { abs($0 - first) < 0.0001 }
    }
}
