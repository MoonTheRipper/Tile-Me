import Foundation

struct PlannedShortcutRegistration: Equatable {
    let identifier: String
    let keyCode: UInt16
    let modifiersRawValue: UInt
    let command: ShortcutCommand
}

struct ShortcutRegistrationPlanner {
    func registrations(for profile: WorkspaceProfile) -> [PlannedShortcutRegistration] {
        ShortcutAction.supportedActions.compactMap { action -> [PlannedShortcutRegistration]? in
            guard let binding = profile.shortcut(for: action) else {
                return nil
            }

            var registrations = [
                PlannedShortcutRegistration(
                    identifier: action.id,
                    keyCode: binding.keyCode,
                    modifiersRawValue: binding.modifiersRawValue,
                    command: .action(action)
                )
            ]

            if
                action.supportsAdditionalDisplayModifier,
                let additionalModifiers = binding.additionalDisplayModifiersRawValue,
                additionalModifiers != 0,
                case let .moveToTile(index) = action
            {
                registrations.append(
                    PlannedShortcutRegistration(
                        identifier: "\(action.id).nextDisplay",
                        keyCode: binding.keyCode,
                        modifiersRawValue: binding.modifiersRawValue | additionalModifiers,
                        command: .moveToTileOnNextDisplay(index: index)
                    )
                )
            }

            return registrations
        }
        .flatMap { $0 }
    }
}
