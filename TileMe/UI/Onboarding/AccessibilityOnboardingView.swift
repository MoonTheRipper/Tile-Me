import SwiftUI

struct AccessibilityOnboardingView: View {
    @EnvironmentObject private var permissionStore: AccessibilityPermissionStore

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: permissionStore.status.symbolName)
                .font(.title3)
                .foregroundStyle(permissionStore.status.isGranted ? .green : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 8) {
                Text(permissionStore.status.title)
                    .fontWeight(.semibold)

                Text(permissionStore.status.detail)
                    .foregroundStyle(.secondary)

                if permissionStore.status.isGranted {
                    Text("Tile Me stays idle until you choose a menu action or use a registered shortcut.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable access in three steps:")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text("1. Open Accessibility Settings.")
                        Text("2. Turn on Tile Me in the Accessibility list.")
                        Text("3. Return here and choose Refresh Status.")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if !permissionStore.status.isGranted {
                        Button("Request Access") {
                            permissionStore.requestPermission()
                            permissionStore.refreshStatus()
                        }

                        Button("Open Accessibility Settings") {
                            _ = permissionStore.openAccessibilitySettings()
                        }
                    }

                    Button("Recheck Accessibility Status") {
                        permissionStore.refreshStatus()
                    }
                }
                .controlSize(.small)
            }
            .font(.callout)
        }
        .padding(.vertical, 4)
        .onAppear {
            permissionStore.refreshStatus()
        }
    }
}
