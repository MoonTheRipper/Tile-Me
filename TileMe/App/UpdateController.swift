import AppKit
import Foundation

@MainActor
final class UpdateController: ObservableObject {
    @Published private(set) var automaticallyChecksEnabled: Bool
    @Published private(set) var isCheckingForUpdates = false

    private let currentVersion: SemanticVersion?
    private let releaseChecker: any LatestReleaseChecking
    private let decisionEngine: UpdateDecisionEngine
    private let defaults: UserDefaults
    private let workspace: NSWorkspace
    private let nowProvider: @Sendable () -> Date

    private var launchCheckScheduled = false
    private var promptedVersionsThisSession = Set<String>()

    init(
        currentVersionString: String,
        releaseChecker: any LatestReleaseChecking = GitHubLatestReleaseService(),
        decisionEngine: UpdateDecisionEngine = UpdateDecisionEngine(),
        defaults: UserDefaults = .standard,
        workspace: NSWorkspace = .shared,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        currentVersion = SemanticVersion(currentVersionString)
        self.releaseChecker = releaseChecker
        self.decisionEngine = decisionEngine
        self.defaults = defaults
        self.workspace = workspace
        self.nowProvider = nowProvider
        automaticallyChecksEnabled = defaults.object(forKey: ReleaseConfiguration.automaticUpdateChecksDefaultsKey) == nil
            ? true
            : defaults.bool(forKey: ReleaseConfiguration.automaticUpdateChecksDefaultsKey)
    }

    func setAutomaticallyChecksEnabled(_ enabled: Bool) {
        automaticallyChecksEnabled = enabled
        defaults.set(enabled, forKey: ReleaseConfiguration.automaticUpdateChecksDefaultsKey)
    }

    func scheduleAutomaticLaunchCheck() {
        guard automaticallyChecksEnabled, !launchCheckScheduled else {
            return
        }

        launchCheckScheduled = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            await performUpdateCheck(userInitiated: false)
        }
    }

    func checkForUpdatesManually() {
        Task { @MainActor in
            await performUpdateCheck(userInitiated: true)
        }
    }

    private func performUpdateCheck(userInitiated: Bool) async {
        guard !isCheckingForUpdates else {
            return
        }

        guard let currentVersion else {
            if userInitiated {
                presentSimpleAlert(
                    title: "Unable to Check for Updates",
                    message: "Tile Me could not read its current version."
                )
            }
            return
        }

        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }

        do {
            let latestRelease = try await releaseChecker.fetchLatestRelease()
            let decision = decisionEngine.decide(
                currentVersion: currentVersion,
                latestRelease: latestRelease,
                skippedVersion: skippedVersion,
                remindAfterDate: remindAfterDate,
                now: nowProvider(),
                isUserInitiated: userInitiated
            )

            switch decision {
            case let .updateAvailable(availability):
                let versionID = availability.latestVersion.description
                if !userInitiated && promptedVersionsThisSession.contains(versionID) {
                    return
                }

                promptedVersionsThisSession.insert(versionID)
                presentUpdateAlert(for: availability)

            case let .suppressed(reason):
                if userInitiated {
                    switch reason {
                    case .noNewerVersion, .skippedVersion, .remindLater:
                        presentSimpleAlert(
                            title: "Tile Me Is Up to Date",
                            message: "You’re using Tile Me \(currentVersion). No newer release is available right now."
                        )
                    case .invalidLatestVersion:
                        presentSimpleAlert(
                            title: "Unable to Check for Updates",
                            message: "Tile Me could not verify the latest release right now."
                        )
                    }
                }
            }
        } catch {
            if userInitiated {
                presentSimpleAlert(
                    title: "Unable to Check for Updates",
                    message: "Tile Me couldn’t reach the latest release right now. Please try again later."
                )
            }
        }
    }

    private func presentUpdateAlert(for availability: UpdateAvailability) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "Tile Me \(availability.latestVersion) is available. You’re using \(availability.currentVersion)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download Update")
        alert.addButton(withTitle: "Remind Me Later")
        alert.addButton(withTitle: "Skip This Version")

        NSApp.activate(ignoringOtherApps: true)

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            clearDeferredUpdateState()
            workspace.open(availability.release.preferredDownloadURL)
        case .alertSecondButtonReturn:
            defaults.set(
                nowProvider().addingTimeInterval(ReleaseConfiguration.updateRemindLaterInterval),
                forKey: ReleaseConfiguration.updateRemindAfterDateDefaultsKey
            )
        default:
            defaults.set(
                availability.latestVersion.description,
                forKey: ReleaseConfiguration.skippedUpdateVersionDefaultsKey
            )
            defaults.removeObject(forKey: ReleaseConfiguration.updateRemindAfterDateDefaultsKey)
        }
    }

    private func presentSimpleAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func clearDeferredUpdateState() {
        defaults.removeObject(forKey: ReleaseConfiguration.skippedUpdateVersionDefaultsKey)
        defaults.removeObject(forKey: ReleaseConfiguration.updateRemindAfterDateDefaultsKey)
    }

    private var skippedVersion: String? {
        defaults.string(forKey: ReleaseConfiguration.skippedUpdateVersionDefaultsKey)
    }

    private var remindAfterDate: Date? {
        defaults.object(forKey: ReleaseConfiguration.updateRemindAfterDateDefaultsKey) as? Date
    }
}
