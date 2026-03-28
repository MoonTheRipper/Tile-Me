import SwiftUI

struct PreferencesSection<Content: View>: View {
    let title: String
    let summary: String
    @ViewBuilder var content: Content

    var body: some View {
        Section {
            content
                .font(.callout)
        } header: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .textCase(nil)
        }
    }
}
