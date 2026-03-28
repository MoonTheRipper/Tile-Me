import CoreGraphics
import Foundation

struct TraversalTileCandidate: Equatable, Sendable {
    let displayID: String
    let tileID: String
    let index: Int
    let frame: CGRect
    let center: CGPoint
    let sortOrder: Int
}

struct TileTraversalService {
    private let layoutEngine: LayoutEngine

    init(layoutEngine: LayoutEngine = LayoutEngine()) {
        self.layoutEngine = layoutEngine
    }

    func resolveCandidates(
        displays: [DisplayProfile],
        workspaceProfile: WorkspaceProfile
    ) -> [TraversalTileCandidate] {
        let sortedDisplays = displays.sorted(by: displaySortComparator)
        var candidates: [TraversalTileCandidate] = []
        candidates.reserveCapacity(sortedDisplays.count * 4)

        for display in sortedDisplays {
            let layoutID = workspaceProfile.resolvedLayoutID(for: display.id)
            let layout = BuiltinLayouts.definition(id: layoutID) ?? BuiltinLayouts.defaultLayout
            let frames = layoutEngine.resolve(layout: layout, in: display.visibleFrame)

            for frame in frames {
                candidates.append(
                    TraversalTileCandidate(
                        displayID: display.id,
                        tileID: frame.tileID,
                        index: frame.index,
                        frame: frame.frame,
                        center: CGPoint(x: frame.frame.midX, y: frame.frame.midY),
                        sortOrder: candidates.count
                    )
                )
            }
        }

        return candidates
    }

    func destination(
        for windowFrame: CGRect,
        direction: TileTraversalDirection,
        currentDisplayID: String?,
        displays: [DisplayProfile],
        workspaceProfile: WorkspaceProfile
    ) -> TraversalTileCandidate? {
        let candidates = resolveCandidates(displays: displays, workspaceProfile: workspaceProfile)
        let displayBoundsByID = Dictionary(uniqueKeysWithValues: displays.map { ($0.id, $0.visibleFrame) })
        guard !candidates.isEmpty else {
            return nil
        }

        guard let currentCandidate = inferCurrentCandidate(
            for: windowFrame,
            preferredDisplayID: currentDisplayID,
            displayBoundsByID: displayBoundsByID,
            candidates: candidates
        ) else {
            return nil
        }

        let preferredDisplayID = currentDisplayID ?? currentCandidate.displayID
        let sameDisplayCandidates = candidates.filter {
            $0.displayID == preferredDisplayID && !isSameTile($0, currentCandidate)
        }

        if let candidate = bestDirectionalCandidate(
            from: currentCandidate,
            in: sameDisplayCandidates,
            direction: direction
        ) {
            return candidate
        }

        let otherDisplayCandidates = candidates.filter {
            $0.displayID != preferredDisplayID && !isSameTile($0, currentCandidate)
        }

        return bestDirectionalCandidate(
            from: currentCandidate,
            in: otherDisplayCandidates,
            direction: direction
        )
    }

    private func inferCurrentCandidate(
        for windowFrame: CGRect,
        preferredDisplayID: String?,
        displayBoundsByID: [String: CGRect],
        candidates: [TraversalTileCandidate]
    ) -> TraversalTileCandidate? {
        let preferredDisplayCandidates = candidates.filter { $0.displayID == preferredDisplayID }
        return bestCurrentMatch(
            for: windowFrame,
            preferredDisplayID: preferredDisplayID,
            displayBoundsByID: displayBoundsByID,
            in: preferredDisplayCandidates
        )?.candidate
            ?? bestCurrentMatch(
                for: windowFrame,
                preferredDisplayID: preferredDisplayID,
                displayBoundsByID: displayBoundsByID,
                in: candidates
            )?.candidate
    }

    private func bestCurrentMatch(
        for windowFrame: CGRect,
        preferredDisplayID: String?,
        displayBoundsByID: [String: CGRect],
        in candidates: [TraversalTileCandidate]
    ) -> CurrentMatch? {
        guard !candidates.isEmpty else {
            return nil
        }

        var framesToEvaluate: [CGRect] = [windowFrame]
        if let preferredDisplayID, let preferredBounds = displayBoundsByID[preferredDisplayID] {
            framesToEvaluate.append(windowFrame.mirroredVertically(within: preferredBounds))
        }

        return framesToEvaluate.enumerated()
            .compactMap { sourceOrder, frame in
                bestCurrentMatch(for: frame, in: candidates, sourceOrder: sourceOrder)
            }
            .min(by: currentMatchComparator)
    }

    private func bestCurrentMatch(
        for windowFrame: CGRect,
        in candidates: [TraversalTileCandidate],
        sourceOrder: Int
    ) -> CurrentMatch? {
        guard !candidates.isEmpty else {
            return nil
        }

        let windowArea = max(windowFrame.area, 1)
        return candidates
            .map { candidate in
                CurrentMatch(
                    candidate: candidate,
                    overlapRatio: candidate.frame.intersection(windowFrame).area / windowArea,
                    centerDistance: candidate.center.distanceSquared(to: windowFrame.center),
                    areaDelta: abs(candidate.frame.area - windowFrame.area),
                    sourceOrder: sourceOrder
                )
            }
            .min(by: currentMatchComparator)
    }

    private func bestDirectionalCandidate(
        from current: TraversalTileCandidate,
        in candidates: [TraversalTileCandidate],
        direction: TileTraversalDirection
    ) -> TraversalTileCandidate? {
        candidates
            .compactMap { candidate -> (TraversalTileCandidate, TraversalScore)? in
                guard let score = score(from: current, to: candidate, direction: direction) else {
                    return nil
                }

                return (candidate, score)
            }
            .min { lhs, rhs in
                if lhs.1.directionalDistance != rhs.1.directionalDistance {
                    return lhs.1.directionalDistance < rhs.1.directionalDistance
                }

                if lhs.1.perpendicularGap != rhs.1.perpendicularGap {
                    return lhs.1.perpendicularGap < rhs.1.perpendicularGap
                }

                if lhs.1.perpendicularCenterDistance != rhs.1.perpendicularCenterDistance {
                    return lhs.1.perpendicularCenterDistance < rhs.1.perpendicularCenterDistance
                }

                return lhs.0.sortOrder < rhs.0.sortOrder
            }?
            .0
    }

    private func score(
        from current: TraversalTileCandidate,
        to candidate: TraversalTileCandidate,
        direction: TileTraversalDirection
    ) -> TraversalScore? {
        let dx = candidate.center.x - current.center.x
        let dy = candidate.center.y - current.center.y
        let intervalsOverlap: Bool
        let directionalComponent: CGFloat
        let perpendicularComponent: CGFloat
        let directionalDistance: CGFloat
        let perpendicularGap: CGFloat

        switch direction {
        case .left:
            directionalComponent = -dx
            perpendicularComponent = dy
            intervalsOverlap = current.frame.verticalOverlap(with: candidate.frame) > 0
            directionalDistance = max(current.frame.minX - candidate.frame.maxX, 0)
            perpendicularGap = current.frame.verticalGap(to: candidate.frame)
        case .right:
            directionalComponent = dx
            perpendicularComponent = dy
            intervalsOverlap = current.frame.verticalOverlap(with: candidate.frame) > 0
            directionalDistance = max(candidate.frame.minX - current.frame.maxX, 0)
            perpendicularGap = current.frame.verticalGap(to: candidate.frame)
        case .up:
            directionalComponent = dy
            perpendicularComponent = dx
            intervalsOverlap = current.frame.horizontalOverlap(with: candidate.frame) > 0
            directionalDistance = max(candidate.frame.minY - current.frame.maxY, 0)
            perpendicularGap = current.frame.horizontalGap(to: candidate.frame)
        case .down:
            directionalComponent = -dy
            perpendicularComponent = dx
            intervalsOverlap = current.frame.horizontalOverlap(with: candidate.frame) > 0
            directionalDistance = max(current.frame.minY - candidate.frame.maxY, 0)
            perpendicularGap = current.frame.horizontalGap(to: candidate.frame)
        }

        guard directionalComponent > 0.5 else {
            return nil
        }

        let isMeaningfullyDirectional = intervalsOverlap || directionalComponent >= abs(perpendicularComponent)
        guard isMeaningfullyDirectional else {
            return nil
        }

        return TraversalScore(
            directionalDistance: directionalDistance,
            perpendicularGap: perpendicularGap,
            perpendicularCenterDistance: abs(perpendicularComponent)
        )
    }

    private func isSameTile(_ lhs: TraversalTileCandidate, _ rhs: TraversalTileCandidate) -> Bool {
        lhs.displayID == rhs.displayID && lhs.tileID == rhs.tileID
    }

    private var displaySortComparator: (DisplayProfile, DisplayProfile) -> Bool {
        { lhs, rhs in
            if lhs.frame.minX != rhs.frame.minX {
                return lhs.frame.minX < rhs.frame.minX
            }

            if lhs.frame.maxY != rhs.frame.maxY {
                return lhs.frame.maxY > rhs.frame.maxY
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var currentMatchComparator: (CurrentMatch, CurrentMatch) -> Bool {
        { lhs, rhs in
            if lhs.overlapRatio != rhs.overlapRatio {
                return lhs.overlapRatio > rhs.overlapRatio
            }

            if lhs.centerDistance != rhs.centerDistance {
                return lhs.centerDistance < rhs.centerDistance
            }

            if lhs.areaDelta != rhs.areaDelta {
                return lhs.areaDelta < rhs.areaDelta
            }

            if lhs.sourceOrder != rhs.sourceOrder {
                return lhs.sourceOrder < rhs.sourceOrder
            }

            return lhs.candidate.sortOrder < rhs.candidate.sortOrder
        }
    }
}

private struct CurrentMatch {
    let candidate: TraversalTileCandidate
    let overlapRatio: CGFloat
    let centerDistance: CGFloat
    let areaDelta: CGFloat
    let sourceOrder: Int
}

private struct TraversalScore {
    let directionalDistance: CGFloat
    let perpendicularGap: CGFloat
    let perpendicularCenterDistance: CGFloat
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    var area: CGFloat {
        width * height
    }

    func mirroredVertically(within bounds: CGRect) -> CGRect {
        CGRect(
            x: minX,
            y: bounds.maxY - (maxY - bounds.minY),
            width: width,
            height: height
        )
    }

    func horizontalOverlap(with other: CGRect) -> CGFloat {
        max(0, min(maxX, other.maxX) - max(minX, other.minX))
    }

    func verticalOverlap(with other: CGRect) -> CGFloat {
        max(0, min(maxY, other.maxY) - max(minY, other.minY))
    }

    func horizontalGap(to other: CGRect) -> CGFloat {
        if horizontalOverlap(with: other) > 0 {
            return 0
        }

        if maxX <= other.minX {
            return other.minX - maxX
        }

        return minX - other.maxX
    }

    func verticalGap(to other: CGRect) -> CGFloat {
        if verticalOverlap(with: other) > 0 {
            return 0
        }

        if maxY <= other.minY {
            return other.minY - maxY
        }

        return minY - other.maxY
    }
}

private extension CGPoint {
    func distanceSquared(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return (dx * dx) + (dy * dy)
    }
}
