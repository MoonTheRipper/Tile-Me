import AppKit
import SwiftUI

enum ReleaseConfiguration {
    static let supportDevelopmentURL = URL(string: "https://ko-fi.com/moontheripper")!
    static let feedbackEmailAddress = "briviamoon@gmail.com"
    static let gitHubProjectURL = URL(string: "https://github.com/moontheripper/Tile-Me")!
    static let gitHubIssuesURL = URL(string: "https://github.com/moontheripper/Tile-Me/issues")!
    static let gitHubLatestReleaseAPIURL = URL(string: "https://api.github.com/repos/moontheripper/Tile-Me/releases/latest")!
    static let welcomeCompletionDefaultsKey = "tileme.release.welcome.completed"
    static let automaticUpdateChecksDefaultsKey = "tileme.release.updates.automaticCheckEnabled"
    static let skippedUpdateVersionDefaultsKey = "tileme.release.updates.skippedVersion"
    static let updateRemindAfterDateDefaultsKey = "tileme.release.updates.remindAfterDate"
    static let updateRemindLaterInterval: TimeInterval = 60 * 60 * 24 * 7

    static var bugReportURL: URL {
        mailtoURL(
            subject: "Tile Me Bug Report",
            body: "Please describe what happened, what you expected, and any steps to reproduce."
        )
    }

    static var featureRequestURL: URL {
        mailtoURL(
            subject: "Tile Me Feature Request",
            body: "Please describe the workflow or feature you would find most useful in Tile Me."
        )
    }

    private static func mailtoURL(subject: String, body: String) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = feedbackEmailAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]

        guard let url = components.url else {
            preconditionFailure("Expected a valid mailto URL for release feedback actions.")
        }

        return url
    }
}

enum ReleaseHelpPage {
    case welcome
    case tutorial

    var windowTitle: String {
        switch self {
        case .welcome:
            return "Welcome to Tile Me"
        case .tutorial:
            return "Tile Me Quick Start"
        }
    }
}

@MainActor
final class WelcomeExperienceStore: ObservableObject {
    @Published private(set) var hasCompletedWelcome: Bool

    private let defaults: UserDefaults
    private let completionKey: String

    init(
        defaults: UserDefaults = .standard,
        completionKey: String = ReleaseConfiguration.welcomeCompletionDefaultsKey
    ) {
        self.defaults = defaults
        self.completionKey = completionKey
        hasCompletedWelcome = defaults.bool(forKey: completionKey)
    }

    func markWelcomeCompleted() {
        defaults.set(true, forKey: completionKey)
        hasCompletedWelcome = true
    }
}

@MainActor
final class ReleaseExperienceController: ObservableObject {
    @Published private(set) var hasCompletedWelcome: Bool
    @Published private(set) var currentHelpPage: ReleaseHelpPage = .welcome

    let supportDevelopmentURL: URL
    let bugReportURL: URL
    let featureRequestURL: URL
    let gitHubProjectURL: URL
    let gitHubIssuesURL: URL
    let feedbackEmailAddress: String

    private let welcomeStore: WelcomeExperienceStore
    private var helpWindowController: NSWindowController?
    private var supportWindowController: NSWindowController?
    private var helpCloseObserver: NSObjectProtocol?
    private var supportCloseObserver: NSObjectProtocol?

    init(
        welcomeStore: WelcomeExperienceStore = WelcomeExperienceStore(),
        supportDevelopmentURL: URL = ReleaseConfiguration.supportDevelopmentURL,
        bugReportURL: URL = ReleaseConfiguration.bugReportURL,
        featureRequestURL: URL = ReleaseConfiguration.featureRequestURL,
        gitHubProjectURL: URL = ReleaseConfiguration.gitHubProjectURL,
        gitHubIssuesURL: URL = ReleaseConfiguration.gitHubIssuesURL,
        feedbackEmailAddress: String = ReleaseConfiguration.feedbackEmailAddress
    ) {
        self.welcomeStore = welcomeStore
        self.supportDevelopmentURL = supportDevelopmentURL
        self.bugReportURL = bugReportURL
        self.featureRequestURL = featureRequestURL
        self.gitHubProjectURL = gitHubProjectURL
        self.gitHubIssuesURL = gitHubIssuesURL
        self.feedbackEmailAddress = feedbackEmailAddress
        hasCompletedWelcome = welcomeStore.hasCompletedWelcome
    }

    func presentWelcomeIfNeeded() {
        guard !hasCompletedWelcome else {
            return
        }

        presentHelp(page: .welcome)
    }

    func presentHelp() {
        presentHelp(page: .tutorial)
    }

    func continueFromWelcome() {
        currentHelpPage = .tutorial
        helpWindowController?.window?.title = currentHelpPage.windowTitle
    }

    func finishHelp() {
        markWelcomeCompleted()
        helpWindowController?.close()
    }

    func presentSupport() {
        if let window = supportWindowController?.window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = SupportWindowView()
            .environmentObject(self)

        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Tile Me Support"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.center()
        window.setContentSize(NSSize(width: 500, height: 330))
        window.collectionBehavior = [.fullScreenNone]

        let controller = NSWindowController(window: window)
        supportWindowController = controller

        supportCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.teardownSupportWindow()
            }
        }

        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
    }

    func openSupportDevelopmentPage() {
        NSWorkspace.shared.open(supportDevelopmentURL)
    }

    func openBugReport() {
        NSWorkspace.shared.open(bugReportURL)
    }

    func openFeatureRequest() {
        NSWorkspace.shared.open(featureRequestURL)
    }

    func openGitHubProject() {
        NSWorkspace.shared.open(gitHubProjectURL)
    }

    func openGitHubIssues() {
        NSWorkspace.shared.open(gitHubIssuesURL)
    }

    private func presentHelp(page: ReleaseHelpPage) {
        currentHelpPage = page

        if let window = helpWindowController?.window {
            window.title = currentHelpPage.windowTitle
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = WelcomeWindowView()
            .environmentObject(self)

        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = currentHelpPage.windowTitle
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.center()
        window.setContentSize(NSSize(width: 520, height: 390))
        window.collectionBehavior = [.fullScreenNone]

        let controller = NSWindowController(window: window)
        helpWindowController = controller

        helpCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                if self?.hasCompletedWelcome == false {
                    self?.markWelcomeCompleted()
                }
                self?.teardownHelpWindow()
            }
        }

        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
    }

    private func markWelcomeCompleted() {
        welcomeStore.markWelcomeCompleted()
        hasCompletedWelcome = welcomeStore.hasCompletedWelcome
    }

    private func teardownHelpWindow() {
        if let helpCloseObserver {
            NotificationCenter.default.removeObserver(helpCloseObserver)
            self.helpCloseObserver = nil
        }

        helpWindowController = nil
    }

    private func teardownSupportWindow() {
        if let supportCloseObserver {
            NotificationCenter.default.removeObserver(supportCloseObserver)
            self.supportCloseObserver = nil
        }

        supportWindowController = nil
    }
}
