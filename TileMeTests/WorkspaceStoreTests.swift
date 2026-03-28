import Foundation
import XCTest
@testable import TileMe

final class WorkspaceStoreTests: XCTestCase {
    func testWorkspaceProfileCopiesResolvedLayoutFromAnotherDisplay() {
        var profile = WorkspaceProfile()
        profile.setLayout(id: BuiltinLayouts.grid3x3.id, for: "display-a")
        profile.copyLayout(from: "display-a", for: "display-b")

        XCTAssertEqual(profile.resolvedLayoutID(for: "display-b"), BuiltinLayouts.grid3x3.id)

        profile.setLayout(id: BuiltinLayouts.grid4x4.id, for: "display-a")

        XCTAssertEqual(profile.resolvedLayoutID(for: "display-b"), BuiltinLayouts.grid3x3.id)
    }

    func testWorkspaceProfileMirrorsLayoutsAcrossDisplays() {
        var profile = WorkspaceProfile()
        profile.setLayout(id: BuiltinLayouts.grid3x3.id, for: "display-a")
        profile.mirrorLayout(from: "display-a", for: "display-b")
        profile.mirrorLayout(from: "display-b", for: "display-c")

        XCTAssertEqual(profile.resolvedLayoutID(for: "display-c"), BuiltinLayouts.grid3x3.id)

        profile.setLayout(id: BuiltinLayouts.grid4x4.id, for: "display-a")

        XCTAssertEqual(profile.resolvedLayoutID(for: "display-c"), BuiltinLayouts.grid4x4.id)
    }

    func testWorkspaceProfileBreaksMirrorCycles() {
        var profile = WorkspaceProfile()
        profile.mirrorLayout(from: "display-b", for: "display-a")
        profile.mirrorLayout(from: "display-a", for: "display-b")

        XCTAssertEqual(profile.resolvedLayoutID(for: "display-a"), WorkspaceProfile.defaultLayoutID)
    }

    func testWorkspaceStoreRoundTripsPersistedProfile() throws {
        let suiteName = "TileMeTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated user defaults")
            return
        }

        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let shortcut = ShortcutBinding(keyCode: 18, modifiersRawValue: 1 << 20, additionalDisplayModifiersRawValue: 1 << 17)
        let store = WorkspaceStore(defaults: defaults, storageKey: "workspace-tests")

        store.update { profile in
            profile.setLayout(id: BuiltinLayouts.grid2x2.id, for: "display-a")
            profile.copyLayout(from: "display-a", for: "display-b")
            profile.mirrorLayout(from: "display-b", for: "display-c")
            profile.setShortcut(shortcut, for: .moveToTile(index: 0))
        }

        let reloadedStore = WorkspaceStore(defaults: defaults, storageKey: "workspace-tests")

        XCTAssertEqual(reloadedStore.profile.resolvedLayoutID(for: "display-b"), BuiltinLayouts.grid2x2.id)
        XCTAssertEqual(reloadedStore.profile.mode(for: "display-b"), .copiedLayout)
        XCTAssertEqual(reloadedStore.profile.mode(for: "display-c"), .mirroredDisplay)
        XCTAssertEqual(reloadedStore.profile.shortcut(for: .moveToTile(index: 0)), shortcut)
    }

    func testWorkspaceStoreMigratesLegacyStorageKey() throws {
        let suiteName = "TileMeTests.Legacy.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated user defaults")
            return
        }

        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let legacyProfile = WorkspaceProfile(
            displayAssignments: [
                "display-a": DisplayLayoutAssignment(source: .layout(id: BuiltinLayouts.grid3x3.id))
            ],
            shortcuts: ShortcutAction.defaultBindings
        )
        let data = try JSONEncoder().encode(legacyProfile)
        defaults.set(data, forKey: "workspace_profile")

        let store = WorkspaceStore(defaults: defaults, storageKey: "workspace_profile_v1")

        XCTAssertEqual(store.profile.resolvedLayoutID(for: "display-a"), BuiltinLayouts.grid3x3.id)
        XCTAssertNil(defaults.data(forKey: "workspace_profile"))
        XCTAssertNotNil(defaults.data(forKey: "workspace_profile_v1"))
    }
}
