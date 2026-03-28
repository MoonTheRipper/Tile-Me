import XCTest
@testable import TileMe

final class TileMeTests: XCTestCase {
    func testBuiltInLayoutLibraryContainsDefaultLayout() {
        XCTAssertTrue(BuiltinLayouts.all.contains(where: { $0.id == BuiltinLayouts.defaultLayout.id }))
    }

    func testNestedLayoutExamplesAreExposedSeparatelyFromMenuPresets() {
        XCTAssertFalse(BuiltinLayouts.all.contains(where: { $0.id == BuiltinLayouts.topPairBottomWide.id }))
        XCTAssertEqual(BuiltinLayouts.nestedExamples.count, 2)
    }

    func testPresetSectionsGroupHalvesAndGridFamiliesForMenus() {
        XCTAssertEqual(BuiltinLayouts.presetSections.map(\.title), ["Halves", "Grid Presets"])
        XCTAssertEqual(BuiltinLayouts.presetSections[0].layouts.map(\.name), ["1x2", "2x1"])
        XCTAssertEqual(BuiltinLayouts.presetSections[1].groups.map(\.title), ["2 Columns", "3 Columns", "4 Columns", "5 Columns"])
        XCTAssertEqual(BuiltinLayouts.presetSections[1].groups[0].layouts.map(\.name), ["2x2", "2x3", "2x4", "2x5"])
        XCTAssertEqual(BuiltinLayouts.presetSections[1].groups[3].layouts.map(\.name), ["5x2", "5x3", "5x4", "5x5"])
    }

    @MainActor
    func testDisplayManagerUsesInjectedDiscoveryAndSortsDisplays() {
        let manager = DisplayManager(
            notificationCenter: NotificationCenter(),
            displayDiscovery: StubDisplayDiscovery(
                displays: [
                    DisplayProfile(
                        id: "right",
                        name: "Right Display",
                        frame: CGRect(x: 1200, y: 0, width: 1200, height: 800),
                        visibleFrame: CGRect(x: 1200, y: 0, width: 1200, height: 760),
                        scale: 2,
                        isBuiltIn: false
                    ),
                    DisplayProfile(
                        id: "left",
                        name: "Left Display",
                        frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
                        visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 760),
                        scale: 2,
                        isBuiltIn: true
                    ),
                ]
            )
        )

        XCTAssertEqual(manager.displays.map(\.id), ["left", "right"])
        XCTAssertEqual(manager.nextDisplay(after: "left")?.id, "right")
    }
}

private struct StubDisplayDiscovery: DisplayDiscovering {
    let displays: [DisplayProfile]

    func discoverDisplays() -> [DisplayProfile] {
        displays
    }
}
