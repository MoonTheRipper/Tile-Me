import XCTest
@testable import TileMe

@MainActor
final class WelcomeExperienceStoreTests: XCTestCase {
    func testWelcomeStoreDefaultsToIncompleteAndPersistsCompletion() {
        let suiteName = "TileMeTests.Welcome.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Expected isolated UserDefaults suite.")
        }

        defaults.removePersistentDomain(forName: suiteName)

        let store = WelcomeExperienceStore(defaults: defaults, completionKey: "welcome.completed")
        XCTAssertFalse(store.hasCompletedWelcome)

        store.markWelcomeCompleted()
        XCTAssertTrue(store.hasCompletedWelcome)

        let reloadedStore = WelcomeExperienceStore(defaults: defaults, completionKey: "welcome.completed")
        XCTAssertTrue(reloadedStore.hasCompletedWelcome)
    }
}
