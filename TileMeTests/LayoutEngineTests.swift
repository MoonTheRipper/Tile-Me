import CoreGraphics
import XCTest
@testable import TileMe

final class LayoutEngineTests: XCTestCase {
    private let engine = LayoutEngine()

    func testHalvesLayoutResolvesLeftAndRightTiles() {
        let bounds = CGRect(x: 0, y: 0, width: 1200, height: 800)

        let frames = engine.resolve(layout: BuiltinLayouts.halves, in: bounds)

        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(frames[0].index, 0)
        XCTAssertEqual(frames[0].tileID, "halves-left")
        XCTAssertEqual(frames[0].frame, CGRect(x: 0, y: 0, width: 600, height: 800))
        XCTAssertEqual(frames[1].index, 1)
        XCTAssertEqual(frames[1].tileID, "halves-right")
        XCTAssertEqual(frames[1].frame, CGRect(x: 600, y: 0, width: 600, height: 800))
    }

    func testVerticalHalvesLayoutResolvesTopAndBottomTiles() {
        let bounds = CGRect(x: 0, y: 0, width: 1200, height: 800)

        let frames = engine.resolve(layout: BuiltinLayouts.halves1x2, in: bounds)

        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(frames[0].tileID, "halves-top")
        XCTAssertEqual(frames[0].frame, CGRect(x: 0, y: 400, width: 1200, height: 400))
        XCTAssertEqual(frames[1].tileID, "halves-bottom")
        XCTAssertEqual(frames[1].frame, CGRect(x: 0, y: 0, width: 1200, height: 400))
    }

    func testGridLayoutUsesReadingOrderAndStableTileIdentifiers() {
        let bounds = CGRect(x: 0, y: 0, width: 900, height: 900)

        let frames = engine.resolve(layout: BuiltinLayouts.grid3x3, in: bounds)

        XCTAssertEqual(frames.count, 9)
        XCTAssertEqual(frames.map(\.tileID), BuiltinLayouts.grid3x3.tileIDs)
        XCTAssertEqual(frames[0].tileID, "grid-3x3-r1-c1")
        XCTAssertEqual(frames[0].frame, CGRect(x: 0, y: 600, width: 300, height: 300))
        XCTAssertEqual(frames[1].tileID, "grid-3x3-r1-c2")
        XCTAssertEqual(frames[1].frame, CGRect(x: 300, y: 600, width: 300, height: 300))
        XCTAssertEqual(frames[8].tileID, "grid-3x3-r3-c3")
        XCTAssertEqual(frames[8].frame, CGRect(x: 600, y: 0, width: 300, height: 300))
    }

    func testClosestTileIndexFindsNearestResolvedTile() {
        let bounds = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let target = CGRect(x: 700, y: 10, width: 400, height: 780)

        let closestIndex = engine.closestTileIndex(to: target, in: BuiltinLayouts.halves, bounds: bounds)

        XCTAssertEqual(closestIndex, 1)
    }

    func testGridHelperIsReadyForEightByEightLayouts() {
        let layout = BuiltinLayouts.grid(id: "grid-8x8", name: "8x8", columns: 8, rows: 8)
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 800)

        let frames = engine.resolve(layout: layout, in: bounds)

        XCTAssertEqual(layout.tileCount, 64)
        XCTAssertEqual(layout.root.id, "grid-8x8-root")
        XCTAssertEqual(layout.tileIDs.first, "grid-8x8-r1-c1")
        XCTAssertEqual(layout.tileIDs.last, "grid-8x8-r8-c8")
        XCTAssertEqual(frames.count, 64)
        XCTAssertEqual(frames[0].frame, CGRect(x: 0, y: 700, width: 100, height: 100))
        XCTAssertEqual(frames.last?.frame, CGRect(x: 700, y: 0, width: 100, height: 100))
    }

    func testGridPresetFamilyCoversTwoThroughFiveColumnsAndRows() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 1000)

        XCTAssertEqual(BuiltinLayouts.gridPresets.count, 16)
        XCTAssertEqual(BuiltinLayouts.all.count, 18)

        for columns in 2...5 {
            let presets = BuiltinLayouts.gridPresetsByColumns[columns]

            XCTAssertEqual(presets?.map(\.name), ["\(columns)x2", "\(columns)x3", "\(columns)x4", "\(columns)x5"])

            for rows in 2...5 {
                guard let layout = presets?.first(where: { $0.name == "\(columns)x\(rows)" }) else {
                    XCTFail("Missing preset \(columns)x\(rows)")
                    continue
                }

                let frames = engine.resolve(layout: layout, in: bounds)

                XCTAssertEqual(layout.tileCount, columns * rows)
                XCTAssertEqual(layout.tileIDs.first, "grid-\(columns)x\(rows)-r1-c1")
                XCTAssertEqual(layout.tileIDs.last, "grid-\(columns)x\(rows)-r\(rows)-c\(columns)")
                XCTAssertEqual(frames.count, columns * rows)
            }
        }
    }

    func testNestedSplitExampleResolvesExpectedFrames() {
        let bounds = CGRect(x: 0, y: 0, width: 1200, height: 900)

        let frames = engine.resolve(layout: BuiltinLayouts.topPairBottomWide, in: bounds)

        XCTAssertEqual(frames.map(\.tileID), [
            "nested-top-pair-bottom-wide-top-left",
            "nested-top-pair-bottom-wide-top-right",
            "nested-top-pair-bottom-wide-bottom",
        ])
        XCTAssertEqual(frames[0].frame, CGRect(x: 0, y: 300, width: 600, height: 600))
        XCTAssertEqual(frames[1].frame, CGRect(x: 600, y: 300, width: 600, height: 600))
        XCTAssertEqual(frames[2].frame, CGRect(x: 0, y: 0, width: 1200, height: 300))
    }

    func testStableNodeIdentifiersArePreservedAcrossNestedLayoutHelpers() {
        let layout = BuiltinLayouts.largeLeftStackedRight
        let nodeIDs = layout.root.orderedNodeIDs

        XCTAssertEqual(layout.root.id, "nested-large-left-stacked-right-root")
        XCTAssertEqual(nodeIDs.first, "nested-large-left-stacked-right-root")
        XCTAssertEqual(Set(nodeIDs).count, nodeIDs.count)
        XCTAssertTrue(nodeIDs.contains("nested-large-left-stacked-right-right-stack"))
        XCTAssertEqual(layout.tileIDs, [
            "nested-large-left-stacked-right-left",
            "nested-large-left-stacked-right-top",
            "nested-large-left-stacked-right-bottom",
        ])
    }

    func testTwoByTwoGridResolvesInsideVisibleFrameWithInsetOrigin() {
        let visibleFrame = CGRect(x: 100, y: 24, width: 1200, height: 736)

        let frames = engine.resolve(layout: BuiltinLayouts.grid2x2, in: visibleFrame)

        XCTAssertEqual(frames.map(\.frame), [
            CGRect(x: 100, y: 392, width: 600, height: 368),
            CGRect(x: 700, y: 392, width: 600, height: 368),
            CGRect(x: 100, y: 24, width: 600, height: 368),
            CGRect(x: 700, y: 24, width: 600, height: 368),
        ])
        XCTAssertTrue(frames.allSatisfy { $0.frame.minY >= visibleFrame.minY })
        XCTAssertTrue(frames.allSatisfy { $0.frame.maxY <= visibleFrame.maxY })
    }

    func testTwoByTwoGridTopAndBottomRowsExactlyPartitionVisibleHeight() {
        let visibleFrame = CGRect(x: 0, y: 23, width: 1200, height: 737)

        let frames = engine.resolve(layout: BuiltinLayouts.grid2x2, in: visibleFrame)
        let topLeft = frames[0].frame
        let bottomLeft = frames[2].frame

        XCTAssertEqual(topLeft.maxY, visibleFrame.maxY)
        XCTAssertEqual(bottomLeft.minY, visibleFrame.minY)
        XCTAssertEqual(topLeft.minY, bottomLeft.maxY)
        XCTAssertEqual(topLeft.height + bottomLeft.height, visibleFrame.height)
    }

    func testCommonGridPresetsStayWithinVisibleFrameBounds() {
        let visibleFrame = CGRect(x: 10, y: 23, width: 1199, height: 737)

        for layout in [BuiltinLayouts.grid2x2, BuiltinLayouts.grid3x3, BuiltinLayouts.grid4x4] {
            let frames = engine.resolve(layout: layout, in: visibleFrame)

            XCTAssertFalse(frames.isEmpty, "Expected \(layout.name) to resolve at least one tile.")
            XCTAssertTrue(
                frames.allSatisfy { $0.frame.minX >= visibleFrame.minX && $0.frame.maxX <= visibleFrame.maxX },
                "Expected every \(layout.name) tile to stay within the visibleFrame width."
            )
            XCTAssertTrue(
                frames.allSatisfy { $0.frame.minY >= visibleFrame.minY && $0.frame.maxY <= visibleFrame.maxY },
                "Expected every \(layout.name) tile to stay within the visibleFrame height."
            )
        }
    }
}
