import AppKit
@preconcurrency import Carbon.HIToolbox
import SwiftUI

struct ShortcutEditorView: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore
    @EnvironmentObject private var shortcutCoordinator: ShortcutCoordinator

    @State private var generalExpanded = true
    @State private var navigationExpanded = true
    @State private var tileExpanded = false
    @State private var quickExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Global shortcuts are registered with native Carbon hotkeys and run Tile Me actions on demand.")
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Restore Defaults") {
                    shortcutCoordinator.restoreDefaults()
                }
                .controlSize(.small)
            }

            if let lastExecutionError = shortcutCoordinator.lastExecutionError {
                Text(lastExecutionError.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let lastExecutionMessage = shortcutCoordinator.lastExecutionMessage {
                Text(lastExecutionMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !shortcutCoordinator.registrationFailures.isEmpty {
                Text("Some shortcuts could not be registered. Duplicate or invalid combinations are ignored.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            DisclosureGroup("General Shortcuts", isExpanded: $generalExpanded) {
                ShortcutSection(actions: ShortcutAction.generalActions)
                    .padding(.top, 8)
            }

            DisclosureGroup("Directional Traversal", isExpanded: $navigationExpanded) {
                ShortcutSection(actions: ShortcutAction.navigationActions)
                    .padding(.top, 8)
            }

            DisclosureGroup("Tile Shortcuts", isExpanded: $tileExpanded) {
                ShortcutSection(actions: ShortcutAction.tileActions)
                    .padding(.top, 8)
            }

            DisclosureGroup("Quick Layout Shortcuts", isExpanded: $quickExpanded) {
                ShortcutSection(actions: ShortcutAction.quickLayoutActions)
                    .padding(.top, 8)
            }
        }
    }
}

private struct ShortcutSection: View {
    let actions: [ShortcutAction]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(actions, id: \.id) { action in
                ShortcutBindingRow(action: action)
            }
        }
    }
}

private struct ShortcutBindingRow: View {
    @EnvironmentObject private var workspaceStore: WorkspaceStore

    let action: ShortcutAction

    private var bindingValue: ShortcutBinding? {
        workspaceStore.profile.shortcut(for: action)
    }

    private var availableKeyOptions: [ShortcutKeyOption] {
        if let currentKeyCode = bindingValue?.keyCode,
           !ShortcutKeyOption.defaults.contains(where: { $0.keyCode == currentKeyCode }) {
            return [ShortcutKeyOption(label: "Key \(currentKeyCode)", keyCode: currentKeyCode)] + ShortcutKeyOption.defaults
        }

        return ShortcutKeyOption.defaults
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(action.title)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Toggle("Enabled", isOn: enabledBinding)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            }

            if enabledBinding.wrappedValue {
                HStack(spacing: 10) {
                    Picker("Key", selection: keyCodeBinding) {
                        ForEach(availableKeyOptions) { option in
                            Text(option.label).tag(option.keyCode)
                        }
                    }
                    .frame(width: 110)

                    Picker("Modifiers", selection: modifiersBinding) {
                        ForEach(ShortcutModifierOption.defaults) { option in
                            Text(option.label).tag(option.rawValue)
                        }
                    }
                    .frame(width: 170)

                    if action.supportsAdditionalDisplayModifier {
                        Picker("Other Display", selection: additionalDisplayModifierBinding) {
                            ForEach(ShortcutAdditionalDisplayModifier.defaults) { option in
                                Text(option.label).tag(option.rawValue)
                            }
                        }
                        .frame(width: 150)
                    }

                    Spacer()
                }
                .controlSize(.small)
            }
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: {
                bindingValue != nil
            },
            set: { isEnabled in
                if isEnabled {
                    workspaceStore.setShortcut(bindingValue ?? action.defaultBinding ?? ShortcutBinding(
                        keyCode: ShortcutKeyOption.defaults.first?.keyCode ?? UInt16(kVK_ANSI_1),
                        modifiersRawValue: ShortcutModifierOption.defaults.first?.rawValue ?? NSEvent.ModifierFlags([.control, .option]).rawValue
                    ), for: action)
                } else {
                    workspaceStore.setShortcut(nil, for: action)
                }
            }
        )
    }

    private var keyCodeBinding: Binding<UInt16> {
        Binding(
            get: {
                bindingValue?.keyCode ?? action.defaultBinding?.keyCode ?? UInt16(kVK_ANSI_1)
            },
            set: { keyCode in
                updateBinding { binding in
                    binding.keyCode = keyCode
                }
            }
        )
    }

    private var modifiersBinding: Binding<UInt> {
        Binding(
            get: {
                bindingValue?.modifiersRawValue ?? action.defaultBinding?.modifiersRawValue ?? ShortcutModifierOption.defaults.first?.rawValue ?? 0
            },
            set: { modifiersRawValue in
                updateBinding { binding in
                    binding.modifiersRawValue = modifiersRawValue
                }
            }
        )
    }

    private var additionalDisplayModifierBinding: Binding<UInt> {
        Binding(
            get: {
                bindingValue?.additionalDisplayModifiersRawValue ?? action.defaultBinding?.additionalDisplayModifiersRawValue ?? 0
            },
            set: { rawValue in
                updateBinding { binding in
                    binding.additionalDisplayModifiersRawValue = rawValue == 0 ? nil : rawValue
                }
            }
        )
    }

    private func updateBinding(_ update: (inout ShortcutBinding) -> Void) {
        var binding = bindingValue ?? action.defaultBinding ?? ShortcutBinding(
            keyCode: UInt16(kVK_ANSI_1),
            modifiersRawValue: ShortcutModifierOption.defaults.first?.rawValue ?? 0
        )
        update(&binding)
        workspaceStore.setShortcut(binding, for: action)
    }
}

private struct ShortcutKeyOption: Identifiable, Equatable {
    let label: String
    let keyCode: UInt16

    var id: UInt16 {
        keyCode
    }

    static let defaults: [ShortcutKeyOption] = [
        ShortcutKeyOption(label: "1", keyCode: UInt16(kVK_ANSI_1)),
        ShortcutKeyOption(label: "2", keyCode: UInt16(kVK_ANSI_2)),
        ShortcutKeyOption(label: "3", keyCode: UInt16(kVK_ANSI_3)),
        ShortcutKeyOption(label: "4", keyCode: UInt16(kVK_ANSI_4)),
        ShortcutKeyOption(label: "5", keyCode: UInt16(kVK_ANSI_5)),
        ShortcutKeyOption(label: "6", keyCode: UInt16(kVK_ANSI_6)),
        ShortcutKeyOption(label: "7", keyCode: UInt16(kVK_ANSI_7)),
        ShortcutKeyOption(label: "8", keyCode: UInt16(kVK_ANSI_8)),
        ShortcutKeyOption(label: "9", keyCode: UInt16(kVK_ANSI_9)),
        ShortcutKeyOption(label: "0", keyCode: UInt16(kVK_ANSI_0)),
        ShortcutKeyOption(label: "A", keyCode: UInt16(kVK_ANSI_A)),
        ShortcutKeyOption(label: "B", keyCode: UInt16(kVK_ANSI_B)),
        ShortcutKeyOption(label: "C", keyCode: UInt16(kVK_ANSI_C)),
        ShortcutKeyOption(label: "D", keyCode: UInt16(kVK_ANSI_D)),
        ShortcutKeyOption(label: "E", keyCode: UInt16(kVK_ANSI_E)),
        ShortcutKeyOption(label: "F", keyCode: UInt16(kVK_ANSI_F)),
        ShortcutKeyOption(label: "G", keyCode: UInt16(kVK_ANSI_G)),
        ShortcutKeyOption(label: "H", keyCode: UInt16(kVK_ANSI_H)),
        ShortcutKeyOption(label: "I", keyCode: UInt16(kVK_ANSI_I)),
        ShortcutKeyOption(label: "J", keyCode: UInt16(kVK_ANSI_J)),
        ShortcutKeyOption(label: "K", keyCode: UInt16(kVK_ANSI_K)),
        ShortcutKeyOption(label: "L", keyCode: UInt16(kVK_ANSI_L)),
        ShortcutKeyOption(label: "M", keyCode: UInt16(kVK_ANSI_M)),
        ShortcutKeyOption(label: "N", keyCode: UInt16(kVK_ANSI_N)),
        ShortcutKeyOption(label: "O", keyCode: UInt16(kVK_ANSI_O)),
        ShortcutKeyOption(label: "P", keyCode: UInt16(kVK_ANSI_P)),
        ShortcutKeyOption(label: "Q", keyCode: UInt16(kVK_ANSI_Q)),
        ShortcutKeyOption(label: "R", keyCode: UInt16(kVK_ANSI_R)),
        ShortcutKeyOption(label: "S", keyCode: UInt16(kVK_ANSI_S)),
        ShortcutKeyOption(label: "T", keyCode: UInt16(kVK_ANSI_T)),
        ShortcutKeyOption(label: "U", keyCode: UInt16(kVK_ANSI_U)),
        ShortcutKeyOption(label: "V", keyCode: UInt16(kVK_ANSI_V)),
        ShortcutKeyOption(label: "W", keyCode: UInt16(kVK_ANSI_W)),
        ShortcutKeyOption(label: "X", keyCode: UInt16(kVK_ANSI_X)),
        ShortcutKeyOption(label: "Y", keyCode: UInt16(kVK_ANSI_Y)),
        ShortcutKeyOption(label: "Z", keyCode: UInt16(kVK_ANSI_Z)),
        ShortcutKeyOption(label: "Left Arrow", keyCode: UInt16(kVK_LeftArrow)),
        ShortcutKeyOption(label: "Right Arrow", keyCode: UInt16(kVK_RightArrow)),
        ShortcutKeyOption(label: "Up Arrow", keyCode: UInt16(kVK_UpArrow)),
        ShortcutKeyOption(label: "Down Arrow", keyCode: UInt16(kVK_DownArrow)),
    ]
}

private struct ShortcutModifierOption: Identifiable, Equatable {
    let label: String
    let rawValue: UInt

    var id: UInt {
        rawValue
    }

    static let defaults: [ShortcutModifierOption] = [
        ShortcutModifierOption(label: "Control + Option", rawValue: NSEvent.ModifierFlags([.control, .option]).rawValue),
        ShortcutModifierOption(label: "Control + Shift", rawValue: NSEvent.ModifierFlags([.control, .shift]).rawValue),
        ShortcutModifierOption(label: "Command + Option", rawValue: NSEvent.ModifierFlags([.command, .option]).rawValue),
        ShortcutModifierOption(label: "Command + Control", rawValue: NSEvent.ModifierFlags([.command, .control]).rawValue),
        ShortcutModifierOption(label: "Command + Option + Shift", rawValue: NSEvent.ModifierFlags([.command, .option, .shift]).rawValue),
    ]
}

private struct ShortcutAdditionalDisplayModifier: Identifiable, Equatable {
    let label: String
    let rawValue: UInt

    var id: UInt {
        rawValue
    }

    static let defaults: [ShortcutAdditionalDisplayModifier] = [
        ShortcutAdditionalDisplayModifier(label: "None", rawValue: 0),
        ShortcutAdditionalDisplayModifier(label: "Shift", rawValue: NSEvent.ModifierFlags.shift.rawValue),
        ShortcutAdditionalDisplayModifier(label: "Control", rawValue: NSEvent.ModifierFlags.control.rawValue),
        ShortcutAdditionalDisplayModifier(label: "Option", rawValue: NSEvent.ModifierFlags.option.rawValue),
        ShortcutAdditionalDisplayModifier(label: "Command", rawValue: NSEvent.ModifierFlags.command.rawValue),
    ]
}
