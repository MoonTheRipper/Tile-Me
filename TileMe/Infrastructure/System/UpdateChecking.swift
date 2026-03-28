import Foundation

struct GitHubReleaseAsset: Decodable, Equatable, Sendable {
    let name: String
    let downloadURL: URL

    private enum CodingKeys: String, CodingKey {
        case name
        case downloadURL = "browser_download_url"
    }
}

struct GitHubReleaseMetadata: Equatable, Sendable {
    let tagName: String
    let version: SemanticVersion?
    let pageURL: URL
    let assets: [GitHubReleaseAsset]

    var preferredDownloadURL: URL {
        if let dmgURL = assetURL(withExtension: "dmg") {
            return dmgURL
        }

        if let zipURL = assetURL(withExtension: "zip") {
            return zipURL
        }

        return pageURL
    }

    private func assetURL(withExtension fileExtension: String) -> URL? {
        assets.first(where: { $0.name.lowercased().hasSuffix(".\(fileExtension)") })?.downloadURL
    }
}

enum LatestReleaseError: Error, Equatable {
    case invalidResponse
    case badStatusCode(Int)
}

protocol LatestReleaseChecking: Sendable {
    func fetchLatestRelease() async throws -> GitHubReleaseMetadata
}

struct GitHubLatestReleaseService: LatestReleaseChecking {
    let endpoint: URL
    let session: URLSession

    init(
        endpoint: URL = ReleaseConfiguration.gitHubLatestReleaseAPIURL,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
    }

    func fetchLatestRelease() async throws -> GitHubReleaseMetadata {
        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Tile Me", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LatestReleaseError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LatestReleaseError.badStatusCode(httpResponse.statusCode)
        }

        let release = try JSONDecoder().decode(GitHubLatestReleaseResponse.self, from: data)
        return GitHubReleaseMetadata(
            tagName: release.tagName,
            version: SemanticVersion(release.tagName),
            pageURL: release.pageURL,
            assets: release.assets
        )
    }
}

struct UpdateAvailability: Equatable, Sendable {
    let currentVersion: SemanticVersion
    let release: GitHubReleaseMetadata

    var latestVersion: SemanticVersion {
        release.version ?? currentVersion
    }
}

enum UpdateSuppressionReason: Equatable {
    case noNewerVersion
    case invalidLatestVersion
    case skippedVersion
    case remindLater
}

enum UpdateDecision: Equatable {
    case updateAvailable(UpdateAvailability)
    case suppressed(UpdateSuppressionReason)
}

struct UpdateDecisionEngine {
    func decide(
        currentVersion: SemanticVersion,
        latestRelease: GitHubReleaseMetadata,
        skippedVersion: String?,
        remindAfterDate: Date?,
        now: Date,
        isUserInitiated: Bool
    ) -> UpdateDecision {
        guard let latestVersion = latestRelease.version else {
            return .suppressed(.invalidLatestVersion)
        }

        guard latestVersion > currentVersion else {
            return .suppressed(.noNewerVersion)
        }

        if !isUserInitiated {
            if skippedVersion == latestVersion.description {
                return .suppressed(.skippedVersion)
            }

            if let remindAfterDate, remindAfterDate > now {
                return .suppressed(.remindLater)
            }
        }

        return .updateAvailable(
            UpdateAvailability(
                currentVersion: currentVersion,
                release: latestRelease
            )
        )
    }
}

private struct GitHubLatestReleaseResponse: Decodable {
    let tagName: String
    let pageURL: URL
    let assets: [GitHubReleaseAsset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case pageURL = "html_url"
        case assets
    }
}
