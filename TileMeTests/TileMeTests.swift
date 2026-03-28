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
