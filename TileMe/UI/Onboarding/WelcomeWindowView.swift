import AppKit
import SwiftUI

struct WelcomeWindowView: View {
    @EnvironmentObject private var releaseExperienceController: ReleaseExperienceController

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            switch releaseExperienceController.currentHelpPage {
            case .welcome:
                WelcomePageView()
            case .tutorial:
                TutorialPageView()
            }
        }
        .padding(22)
        .frame(width: 520, height: 390)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle)
                    .font(.title2.weight(.semibold))

                Text(headerSubtitle)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var headerTitle: String {
        switch releaseExperienceController.currentHelpPage {
        case .welcome:
            return "Welcome to Tile Me"
        case .tutorial:
            return "Quick Start"
        }
    }

    private var headerSubtitle: String {
        switch releaseExperienceController.currentHelpPage {
        case .welcome:
            return "A lightweight macOS menu bar app for arranging windows into clean, usable layouts."
        case .tutorial:
            return "A short overview of the shortcuts and places you will use most often."
        }
    }
}

private struct WelcomePageView: View {
    @EnvironmentObject private var releaseExperienceController: ReleaseExperienceController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tile Me helps you tile and organize windows on macOS without getting in the way.")

            Text("I found window tiling on macOS frustrating and wanted to build something useful for everyone.")
                .foregroundStyle(.secondary)

            Label("Accessibility permission is required before Tile Me can inspect or move other apps’ windows.", systemImage: "figure.walk.motion")
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Spacer()

                Button("Continue") {
                    releaseExperienceController.continueFromWelcome()
                }
                .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
    }
}

private struct TutorialPageView: View {
    @EnvironmentObject private var releaseExperienceController: ReleaseExperienceController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tile Me currently works in two practical ways:")

            VStack(alignment: .leading, spacing: 8) {
                Label("Use `Control + Option + 1` through `9` for direct tile placement where that layout exposes those tiles.", systemImage: "key")

                Label("Use `Control + Option + Arrow Keys` to move the focused window toward the next tile in that direction.", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
            }
            .foregroundStyle(.secondary)

            Text("You can adjust these shortcuts later in Settings, along with display assignments and built-in layout choices.")
                .foregroundStyle(.secondary)

            Text("Quick Start can be reopened later from Help in the menu bar or from Settings. Check for Updates is available from the menu bar and Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Spacer()

                Button("Get Started") {
                    releaseExperienceController.finishHelp()
                }
                .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
    }
}

struct SupportWindowView: View {
    @EnvironmentObject private var releaseExperienceController: ReleaseExperienceController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Support Tile Me")
                        .font(.title3.weight(.semibold))

                    Text("Tile Me is built to stay small, useful, and native to macOS.")
                        .foregroundStyle(.secondary)
                }
            }

            Text("If you find it helpful, you can support development, send feedback by email, or use GitHub if you prefer a more technical route.")
                .foregroundStyle(.secondary)

            Text("The simplest feedback path is email. GitHub links are optional for users who already use them.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(releaseExperienceController.feedbackEmailAddress)
                .font(.caption.monospaced())
                .textSelection(.enabled)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button("Support Development") {
                    releaseExperienceController.openSupportDevelopmentPage()
                }

                Button("Report a Bug") {
                    releaseExperienceController.openBugReport()
                }

                Button("Request a Feature") {
                    releaseExperienceController.openFeatureRequest()
                }
            }
            .controlSize(.small)

            HStack(spacing: 8) {
                Button("Open GitHub Issues (Optional)") {
                    releaseExperienceController.openGitHubIssues()
                }

                Button("Open GitHub Project (Optional)") {
                    releaseExperienceController.openGitHubProject()
                }

                Spacer()
            }
            .controlSize(.small)
        }
        .padding(22)
        .frame(width: 500, height: 330)
    }
}
