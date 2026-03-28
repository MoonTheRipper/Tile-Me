import Foundation

@MainActor
final class AppModel: ObservableObject {
    let appName = "Tile Me"

    var versionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        return "Version \(version)"
    }
}
