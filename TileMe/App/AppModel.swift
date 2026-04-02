import Foundation

@MainActor
final class AppModel: ObservableObject {
    let appName = "Tile Me"

    var versionString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.4"
    }

    var currentVersion: SemanticVersion? {
        SemanticVersion(versionString)
    }

    var versionDescription: String {
        "Version \(versionString)"
    }
}
