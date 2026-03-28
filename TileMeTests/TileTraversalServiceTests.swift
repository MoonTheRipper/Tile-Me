import CoreGraphics
import XCTest
@testable import TileMe

final class TileTraversalServiceTests: XCTestCase {
    private let service = TileTraversalService()

    func testTraversalMovesWithinSingleDisplayGrid() {
        let display = DisplayProfile(
            id: "main",
            name: "Main",
            frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 760),
            scale: 2,
            isBuiltIn: true
        )
        var profile = WorkspaceProfile(shortcuts: [:])
        profile.setLayout(id: BuiltinLayouts.grid3x3.id, for: display.id)

        let destination = service.destination(
            for: CGRect(x: 400, y: 253, width: 400, height: 254),
            direction: .right,
            currentDisplayID: display.id,
            displays: [display],
            workspaceProfile: profile
        )

        XCTAssertEqual(destination?.displayID, display.id)
        XCTAssertEqual(destination?.tileID, "grid-3x3-r2-c3")
        XCTAssertEqual(destination?.frame, CGRect(x: 800, y: 254, width: 400, height: 253))
    }

    func testTraversalMovesUpToTileAboveInSingleDisplayGrid() {
        let display = DisplayProfile(
            id: "main",
            name: "Main",
            frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 760),
            scale: 2,
            isBuiltIn: true
        )
        var profile = WorkspaceProfile(shortcuts: [:])
        profile.setLayout(id: BuiltinLayouts.grid3x3.id, for: display.id)

        let destination = service.destination(
            for: CGRect(x: 400, y: 253, width: 400, height: 254),
            direction: .up,
            currentDisplayID: display.id,
            displays: [display],
            workspaceProfile: profile
        )

        XCTAssertEqual(destination?.displayID, display.id)
        XCTAssertEqual(destination?.tileID, "grid-3x3-r1-c2")
        XCTAssertEqual(destination?.frame, CGRect(x: 400, y: 507, width: 400, height: 253))
    }

    func testTraversalMovesDownToTileBelowInSingleDisplayGrid() {
        let display = DisplayProfile(
            id: "main",
            name: "Main",
            frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 760),
            scale: 2,
            isBuiltIn: true
        )
        var profile = WorkspaceProfile(shortcuts: [:])
        profile.setLayout(id: BuiltinLayouts.grid3x3.id, for: display.id)

        let destination = service.destination(
            for: CGRect(x: 400, y: 253, width: 400, height: 254),
            direction: .down,
            currentDisplayID: display.id,
            displays: [display],
            workspaceProfile: profile
        )

        XCTAssertEqual(destination?.displayID, display.id)
        XCTAssertEqual(destination?.tileID, "grid-3x3-r3-c2")
        XCTAssertEqual(destination?.frame, CGRect(x: 400, y: 0, width: 400, height: 254))
    }

    func testTraversalMovesThroughNestedUnevenLayout() {
        let display = DisplayProfile(
            id: "main",
            name: "Main",
            frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 760),
            scale: 2,
            isBuiltIn: true
        )
        var profile = WorkspaceProfile(shortcuts: [:])
        profile.setLayout(id: BuiltinLayouts.largeLeftStackedRight.id, for: display.id)

        let destination = service.destination(
            for: CGRect(x: 720, y: 380, width: 480, height: 380),
            direction: .down,
            currentDisplayID: display.id,
            displays: [display],
            workspaceProfile: profile
        )

        XCTAssertEqual(destination?.tileID, "nested-large-left-stacked-right-bottom")
        XCTAssertEqual(destination?.frame, CGRect(x: 720, y: 0, width: 480, height: 380))
    }

    func testTraversalContinuesAcrossDisplaysWhenCurrentDisplayHasNoCandidate() {
        let leftDisplay = DisplayProfile(
            id: "left",
            name: "Left",
            frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 760),
            scale: 2,
            isBuiltIn: true
        )
        let rightDisplay = DisplayProfile(
            id: "right",
            name: "Right",
            frame: CGRect(x: 1200, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 1200, y: 0, width: 1440, height: 860),
            scale: 2,
            isBuiltIn: false
        )
        var profile = WorkspaceProfile(shortcuts: [:])
        profile.setLayout(id: BuiltinLayouts.halves.id, for: leftDisplay.id)
        profile.setLayout(id: BuiltinLayouts.halves.id, for: rightDisplay.id)

        let destination = service.destination(
            for: CGRect(x: 600, y: 0, width: 600, height: 760),
            direction: .right,
            currentDisplayID: leftDisplay.id,
            displays: [leftDisplay, rightDisplay],
            workspaceProfile: profile
        )

        XCTAssertEqual(destination?.displayID, rightDisplay.id)
        XCTAssertEqual(destination?.tileID, "halves-left")
        XCTAssertEqual(destination?.frame, CGRect(x: 1200, y: 0, width: 720, height: 860))
    }

    func testTraversalMovesAcrossDisplaysVerticallyWhenNoLocalCandidateExists() {
        let lowerDisplay = DisplayProfile(
            id: "lower",
            name: "Lower",
            frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 760),
            scale: 2,
            isBuiltIn: true
        )
        let upperDisplay = DisplayProfile(
            id: "upper",
            name: "Upper",
            frame: CGRect(x: 0, y: 760, width: 1200, height: 800),
            visibleFrame: CGRect(x: 0, y: 760, width: 1200, height: 760),
            scale: 2,
            isBuiltIn: false
        )
        var profile = WorkspaceProfile(shortcuts: [:])
        profile.setLayout(id: BuiltinLayouts.grid2x2.id, for: lowerDisplay.id)
        profile.setLayout(id: BuiltinLayouts.grid2x2.id, for: upperDisplay.id)

        let upwardDestination = service.destination(
            for: CGRect(x: 600, y: 380, width: 600, height: 380),
            direction: .up,
            currentDisplayID: lowerDisplay.id,
            displays: [lowerDisplay, upperDisplay],
            workspaceProfile: profile
        )

        XCTAssertEqual(upwardDestination?.displayID, upperDisplay.id)
        XCTAssertEqual(upwardDestination?.tileID, "grid-2x2-r2-c2")
        XCTAssertEqual(upwardDestination?.frame, CGRect(x: 600, y: 760, width: 600, height: 380))

        let downwardDestination = service.destination(
            for: CGRect(x: 0, y: 760, width: 600, height: 380),
            direction: .down,
            currentDisplayID: upperDisplay.id,
            displays: [lowerDisplay, upperDisplay],
            workspaceProfile: profile
        )

        XCTAssertEqual(downwardDestination?.displayID, lowerDisplay.id)
        XCTAssertEqual(downwardDestination?.tileID, "grid-2x2-r1-c1")
        XCTAssertEqual(downwardDestination?.frame, CGRect(x: 0, y: 380, width: 600, height: 380))
    }

    func testTraversalUsesStableTieBreakForSymmetricCandidates() {
        let display = DisplayProfile(
            id: "main",
            name: "Main",
            frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 760),
            scale: 2,
            isBuiltIn: true
        )
        var profile = WorkspaceProfile(shortcuts: [:])
        profile.setLayout(id: BuiltinLayouts.topPairBottomWide.id, for: display.id)

        let destination = service.destination(
            for: CGRect(x: 0, y: 0, width: 1200, height: 253),
            direction: .up,
            currentDisplayID: display.id,
            displays: [display],
            workspaceProfile: profile
        )

        XCTAssertEqual(destination?.tileID, "nested-top-pair-bottom-wide-top-left")
    }

    func testTraversalInfersCurrentTileFromNonAlignedWindowFrame() {
        let display = DisplayProfile(
            id: "main",
            name: "Main",
            frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 760),
            scale: 2,
            isBuiltIn: true
        )
        var profile = WorkspaceProfile(shortcuts: [:])
        profile.setLayout(id: BuiltinLayouts.grid2x2.id, for: display.id)

        let destination = service.destination(
            for: CGRect(x: 700, y: 420, width: 420, height: 250),
            direction: .down,
            currentDisplayID: display.id,
            displays: [display],
            workspaceProfile: profile
        )

        XCTAssertEqual(destination?.tileID, "grid-2x2-r2-c2")
        XCTAssertEqual(destination?.frame, CGRect(x: 600, y: 0, width: 600, height: 380))
    }

    func testTraversalCorrectsVerticallyMirroredInferenceForConstrainedWindowFrame() {
        let display = DisplayProfile(
            id: "main",
            name: "Main",
            frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
            visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 760),
            scale: 2,
            isBuiltIn: true
        )
        var profile = WorkspaceProfile(shortcuts: [:])
        profile.setLayout(id: BuiltinLayouts.topPairBottomWide.id, for: display.id)

        let destination = service.destination(
            for: CGRect(x: 20, y: 12, width: 560, height: 480),
            direction: .down,
            currentDisplayID: display.id,
            displays: [display],
            workspaceProfile: profile
        )

        XCTAssertEqual(destination?.displayID, display.id)
        XCTAssertEqual(destination?.tileID, "nested-top-pair-bottom-wide-bottom")
        XCTAssertEqual(destination?.frame, CGRect(x: 0, y: 0, width: 1200, height: 254))
    }
}
