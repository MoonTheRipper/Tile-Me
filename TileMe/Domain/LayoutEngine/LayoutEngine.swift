import CoreGraphics
import Foundation

struct LayoutEngine {
    func resolve(layout: LayoutDefinition, in bounds: CGRect) -> [TileFrame] {
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
}

private extension CGPoint {
    func distanceSquared(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return (dx * dx) + (dy * dy)
    }
}
