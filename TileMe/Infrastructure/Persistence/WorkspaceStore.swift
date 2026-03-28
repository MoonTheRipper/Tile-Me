import Combine
import Foundation

final class WorkspaceStore: ObservableObject {
    static let currentStorageKey = "workspace_profile_v1"
    static let legacyStorageKeys = ["workspace_profile"]

    @Published private(set) var profile: WorkspaceProfile

    private let defaults: UserDefaults
    private let storageKey: String
    private let encoder = JSONEncoder()

    init(defaults: UserDefaults = .standard, storageKey: String = WorkspaceStore.currentStorageKey) {
        self.defaults = defaults
        self.storageKey = storageKey
        encoder.outputFormatting = [.sortedKeys]

        let loadResult = Self.loadProfile(
            from: defaults,
            key: storageKey,
            legacyKeys: Self.legacyStorageKeys
        )
        self.profile = loadResult.profile ?? WorkspaceProfile()

        if let loadedKey = loadResult.loadedKey, loadedKey != storageKey {
            persist(profile)
            defaults.removeObject(forKey: loadedKey)
        }
    }

    func save(profile: WorkspaceProfile) {
        self.profile = profile
        persist(profile)
    }

    func update(_ updateBlock: (inout WorkspaceProfile) -> Void) {
        var nextProfile = profile
        updateBlock(&nextProfile)

        guard nextProfile != profile else {
            return
        }

        save(profile: nextProfile)
    }

    func setLayout(id: String, for displayID: String) {
        update { profile in
            profile.setLayout(id: id, for: displayID)
        }
    }

    func copyLayout(from sourceDisplayID: String, to targetDisplayID: String) {
        update { profile in
            profile.copyLayout(from: sourceDisplayID, for: targetDisplayID)
        }
    }

    func mirrorLayout(from sourceDisplayID: String, to targetDisplayID: String) {
        update { profile in
            profile.mirrorLayout(from: sourceDisplayID, for: targetDisplayID)
        }
    }

    func promoteResolvedLayoutToOwn(for displayID: String) {
        update { profile in
            profile.promoteResolvedLayoutToOwn(for: displayID)
        }
    }

    func setShortcut(_ binding: ShortcutBinding?, for action: ShortcutAction) {
        update { profile in
            profile.setShortcut(binding, for: action)
        }
    }

    func restoreDefaultShortcuts() {
        update { profile in
            profile.shortcuts = ShortcutAction.defaultBindings
        }
    }

    func reset() {
        profile = WorkspaceProfile()
        defaults.removeObject(forKey: storageKey)
    }

    private func persist(_ profile: WorkspaceProfile) {
        do {
            defaults.set(try encoder.encode(profile), forKey: storageKey)
        } catch {
            assertionFailure("Failed to persist workspace profile: \(error)")
        }
    }

    private static func loadProfile(
        from defaults: UserDefaults,
        key: String,
        legacyKeys: [String]
    ) -> (profile: WorkspaceProfile?, loadedKey: String?) {
        for candidateKey in [key] + legacyKeys {
            guard let data = defaults.data(forKey: candidateKey) else {
                continue
            }

            do {
                return (try JSONDecoder().decode(WorkspaceProfile.self, from: data), candidateKey)
            } catch {
                defaults.removeObject(forKey: candidateKey)
            }
        }

        return (nil, nil)
    }
}
