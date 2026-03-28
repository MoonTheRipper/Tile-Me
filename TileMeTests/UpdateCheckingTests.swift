import Foundation
import XCTest
@testable import TileMe

final class UpdateCheckingTests: XCTestCase {
    func testSemanticVersionParsesAndComparesVersions() {
        XCTAssertEqual(SemanticVersion("1.0.0"), SemanticVersion(major: 1, minor: 0, patch: 0))
        XCTAssertEqual(SemanticVersion("v1.0.1"), SemanticVersion(major: 1, minor: 0, patch: 1))
        XCTAssertTrue(SemanticVersion("1.0.1")! > SemanticVersion("1.0.0")!)
        XCTAssertTrue(SemanticVersion("1.1.0")! > SemanticVersion("1.0.9")!)
    }

    func testSemanticVersionRejectsInvalidStrings() {
        XCTAssertNil(SemanticVersion("1.0"))
        XCTAssertNil(SemanticVersion("1"))
        XCTAssertNil(SemanticVersion("main"))
        XCTAssertNil(SemanticVersion("1.0.beta"))
    }

    func testGitHubReleaseMetadataPrefersDmgAssetForDownloads() {
        let metadata = GitHubReleaseMetadata(
            tagName: "1.0.1",
            version: SemanticVersion("1.0.1"),
            pageURL: URL(string: "https://github.com/moontheripper/Tile-Me/releases/tag/v1.0.1")!,
            assets: [
                GitHubReleaseAsset(
                    name: "Tile-Me-v1.0.1.zip",
                    downloadURL: URL(string: "https://example.com/tileme.zip")!
                ),
                GitHubReleaseAsset(
                    name: "Tile-Me-v1.0.1.dmg",
                    downloadURL: URL(string: "https://example.com/tileme.dmg")!
                ),
            ]
        )

        XCTAssertEqual(metadata.preferredDownloadURL.absoluteString, "https://example.com/tileme.dmg")
    }

    func testUpdateDecisionReturnsUpdateForNewerRelease() {
        let decision = UpdateDecisionEngine().decide(
            currentVersion: SemanticVersion("1.0.0")!,
            latestRelease: release(tagName: "1.0.1"),
            skippedVersion: nil,
            remindAfterDate: nil,
            now: Date(timeIntervalSince1970: 100),
            isUserInitiated: false
        )

        guard case let .updateAvailable(availability) = decision else {
            return XCTFail("Expected a newer release to be available.")
        }

        XCTAssertEqual(availability.currentVersion.description, "1.0.0")
        XCTAssertEqual(availability.latestVersion.description, "1.0.1")
    }

    func testUpdateDecisionSuppressesSkippedVersionForAutomaticChecks() {
        let decision = UpdateDecisionEngine().decide(
            currentVersion: SemanticVersion("1.0.0")!,
            latestRelease: release(tagName: "1.0.1"),
            skippedVersion: "1.0.1",
            remindAfterDate: nil,
            now: Date(timeIntervalSince1970: 100),
            isUserInitiated: false
        )

        XCTAssertEqual(decision, .suppressed(.skippedVersion))
    }

    func testUpdateDecisionSuppressesRemindLaterForAutomaticChecks() {
        let decision = UpdateDecisionEngine().decide(
            currentVersion: SemanticVersion("1.0.0")!,
            latestRelease: release(tagName: "1.0.1"),
            skippedVersion: nil,
            remindAfterDate: Date(timeIntervalSince1970: 1_000),
            now: Date(timeIntervalSince1970: 100),
            isUserInitiated: false
        )

        XCTAssertEqual(decision, .suppressed(.remindLater))
    }

    func testUpdateDecisionManualCheckBypassesSkippedAndRemindLaterState() {
        let decision = UpdateDecisionEngine().decide(
            currentVersion: SemanticVersion("1.0.0")!,
            latestRelease: release(tagName: "1.0.1"),
            skippedVersion: "1.0.1",
            remindAfterDate: Date(timeIntervalSince1970: 1_000),
            now: Date(timeIntervalSince1970: 100),
            isUserInitiated: true
        )

        guard case .updateAvailable = decision else {
            return XCTFail("Expected a manual check to bypass skipped and remind-later state.")
        }
    }

    private func release(tagName: String) -> GitHubReleaseMetadata {
        GitHubReleaseMetadata(
            tagName: tagName,
            version: SemanticVersion(tagName),
            pageURL: URL(string: "https://github.com/moontheripper/Tile-Me/releases/tag/v\(tagName)")!,
            assets: []
        )
    }
}
