import CoreGraphics
import Foundation

enum WindowFitStatus: String, Equatable, Sendable {
    case exactFit
    case nearFit
    case constrainedFit
    case failedFit
}

struct WindowFitEvaluation: Equatable, Sendable {
    let status: WindowFitStatus
    let intendedFrame: CGRect
    let requestedFrame: CGRect
    let actualFrame: CGRect
    let maxOriginDelta: CGFloat
    let maxSizeDelta: CGFloat
    let maxEdgeDelta: CGFloat
    let overlapRatio: CGFloat
    let normalizedCenterDistance: CGFloat
    let isSmallTarget: Bool

    var appearsConstrained: Bool {
        switch status {
        case .exactFit, .nearFit:
            return false
        case .constrainedFit, .failedFit:
            return true
        }
    }

    var conciseMessage: String? {
        switch status {
        case .exactFit, .nearFit:
            return nil
        case .constrainedFit:
            return "Window did not fully fit the target frame."
        case .failedFit:
            return "Window moved, but the target frame was not honored."
        }
    }

    var logSummary: String {
        "fit=\(status.rawValue) intended=\(intendedFrame.debugDescription) requested=\(requestedFrame.debugDescription) actual=\(actualFrame.debugDescription) overlap=\(String(format: "%.2f", overlapRatio)) originDelta=\(String(format: "%.1f", maxOriginDelta)) sizeDelta=\(String(format: "%.1f", maxSizeDelta)) smallTarget=\(isSmallTarget)"
    }
}

struct WindowFitEvaluator {
    var exactTolerance: CGFloat = 1
    var nearOriginTolerance: CGFloat = 8
    var nearSizeTolerance: CGFloat = 12
    var constrainedOverlapThreshold: CGFloat = 0.35
    var constrainedCenterDistanceThreshold: CGFloat = 0.35
    var practicalMinimumSize = CGSize(width: 240, height: 180)

    func evaluate(
        intendedFrame: CGRect,
        requestedFrame: CGRect,
        actualFrame: CGRect
    ) -> WindowFitEvaluation {
        let isSmallTarget = requestedFrame.width < practicalMinimumSize.width || requestedFrame.height < practicalMinimumSize.height
        let adjustedNearOriginTolerance = nearOriginTolerance + (isSmallTarget ? 4 : 0)
        let adjustedNearSizeTolerance = nearSizeTolerance + (isSmallTarget ? 8 : 0)

        let maxOriginDelta = max(
            abs(actualFrame.minX - requestedFrame.minX),
            abs(actualFrame.minY - requestedFrame.minY)
        )
        let maxSizeDelta = max(
            abs(actualFrame.width - requestedFrame.width),
            abs(actualFrame.height - requestedFrame.height)
        )
        let maxEdgeDelta = max(
            abs(actualFrame.minX - requestedFrame.minX),
            abs(actualFrame.minY - requestedFrame.minY),
            abs(actualFrame.maxX - requestedFrame.maxX),
            abs(actualFrame.maxY - requestedFrame.maxY)
        )
        let requestedArea = max(requestedFrame.area, 1)
        let overlapRatio = actualFrame.intersection(requestedFrame).area / requestedArea
        let normalizedCenterDistance = actualFrame.center.distance(to: requestedFrame.center) / max(requestedFrame.diagonalLength, 1)

        let status: WindowFitStatus
        if maxEdgeDelta <= exactTolerance && maxSizeDelta <= exactTolerance {
            status = .exactFit
        } else if maxOriginDelta <= adjustedNearOriginTolerance && maxSizeDelta <= adjustedNearSizeTolerance {
            status = .nearFit
        } else if overlapRatio >= constrainedOverlapThreshold || normalizedCenterDistance <= constrainedCenterDistanceThreshold {
            status = .constrainedFit
        } else {
            status = .failedFit
        }

        return WindowFitEvaluation(
            status: status,
            intendedFrame: intendedFrame,
            requestedFrame: requestedFrame,
            actualFrame: actualFrame,
            maxOriginDelta: maxOriginDelta,
            maxSizeDelta: maxSizeDelta,
            maxEdgeDelta: maxEdgeDelta,
            overlapRatio: overlapRatio,
            normalizedCenterDistance: normalizedCenterDistance,
            isSmallTarget: isSmallTarget
        )
    }
}

private extension CGRect {
    var area: CGFloat {
        width * height
    }

    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    var diagonalLength: CGFloat {
        sqrt((width * width) + (height * height))
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt((dx * dx) + (dy * dy))
    }
}
