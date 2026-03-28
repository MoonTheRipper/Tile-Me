import AppKit
@preconcurrency import Carbon.HIToolbox
import Foundation

struct ShortcutBinding: Codable, Equatable, Hashable, Sendable {
    var keyCode: UInt16
    var modifiersRawValue: UInt
    var additionalDisplayModifiersRawValue: UInt?

    init(keyCode: UInt16, modifiersRawValue: UInt, additionalDisplayModifiersRawValue: UInt? = nil) {
        self.keyCode = keyCode
        self.modifiersRawValue = modifiersRawValue
        self.additionalDisplayModifiersRawValue = additionalDisplayModifiersRawValue
    }

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiersRawValue)
    }

    var additionalDisplayModifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: additionalDisplayModifiersRawValue ?? 0)
    }

    func mergedModifiers(applyingAdditionalDisplayModifier: Bool) -> NSEvent.ModifierFlags {
        var flags = modifiers
        if applyingAdditionalDisplayModifier {
            flags.formUnion(additionalDisplayModifiers)
        }

        return flags
    }
}

typealias ShortcutDescriptor = ShortcutBinding

enum TileTraversalDirection: String, Codable, CaseIterable, Hashable, Sendable {
    case left
    case right
    case up
    case down

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .left:
            return "Left"
        case .right:
            return "Right"
        case .up:
            return "Up"
        case .down:
            return "Down"
        }
    }
}

enum ShortcutAction: Codable, Hashable, Sendable {
    case moveToTile(index: Int)
    case traverse(direction: TileTraversalDirection)
    case maximize
    case moveToNextDisplay
    case moveToNextDisplayPreservingTile
    case leftHalf
    case rightHalf

    private enum CodingKeys: String, CodingKey {
        case kind
        case index
        case direction
    }

    private enum Kind: String, Codable {
        case moveToTile
        case traverse
        case maximize
        case moveToNextDisplay
        case moveToNextDisplayPreservingTile
        case leftHalf
        case rightHalf
    }

    static let maximumTileShortcutCount = 16

    static var supportedActions: [ShortcutAction] {
        tileActions + navigationActions + generalActions + quickLayoutActions
    }

    static var tileActions: [ShortcutAction] {
        (0..<maximumTileShortcutCount).map { ShortcutAction.moveToTile(index: $0) }
    }

    static var navigationActions: [ShortcutAction] {
        TileTraversalDirection.allCases.map { ShortcutAction.traverse(direction: $0) }
    }

    static var generalActions: [ShortcutAction] {
        [.maximize, .moveToNextDisplay, .moveToNextDisplayPreservingTile]
    }

    static var quickLayoutActions: [ShortcutAction] {
        [.leftHalf, .rightHalf]
    }

    static var defaultBindings: [String: ShortcutBinding] {
        Dictionary(uniqueKeysWithValues: supportedActions.compactMap { action in
            guard let binding = action.defaultBinding else {
                return nil
            }

            return (action.id, binding)
        })
    }

    var id: String {
        switch self {
        case let .moveToTile(index):
            return "tile.\(index)"
        case let .traverse(direction):
            return "traverse.\(direction.id)"
        case .maximize:
            return "maximize"
        case .moveToNextDisplay:
            return "display.next"
        case .moveToNextDisplayPreservingTile:
            return "display.next.preserveTile"
        case .leftHalf:
            return "quick.leftHalf"
        case .rightHalf:
            return "quick.rightHalf"
        }
    }

    var title: String {
        switch self {
        case let .moveToTile(index):
            return "Move Focused Window to Tile \(index + 1)"
        case let .traverse(direction):
            return "Traverse Focused Window \(direction.title)"
        case .maximize:
            return "Maximize Focused Window"
        case .moveToNextDisplay:
            return "Move Focused Window to Next Display"
        case .moveToNextDisplayPreservingTile:
            return "Move to Next Display and Preserve Tile"
        case .leftHalf:
            return "Move Focused Window to Left Half"
        case .rightHalf:
            return "Move Focused Window to Right Half"
        }
    }

    var supportsAdditionalDisplayModifier: Bool {
        switch self {
        case .moveToTile:
            return true
        case .traverse, .maximize, .moveToNextDisplay, .moveToNextDisplayPreservingTile, .leftHalf, .rightHalf:
            return false
        }
    }

    var defaultBinding: ShortcutBinding? {
        let defaultModifiers = NSEvent.ModifierFlags([.control, .option]).rawValue
        let displayModifier = NSEvent.ModifierFlags.shift.rawValue

        switch self {
        case let .moveToTile(index):
            switch index {
            case 0:
                return ShortcutBinding(keyCode: UInt16(kVK_ANSI_1), modifiersRawValue: defaultModifiers, additionalDisplayModifiersRawValue: displayModifier)
            case 1:
                return ShortcutBinding(keyCode: UInt16(kVK_ANSI_2), modifiersRawValue: defaultModifiers, additionalDisplayModifiersRawValue: displayModifier)
            case 2:
                return ShortcutBinding(keyCode: UInt16(kVK_ANSI_3), modifiersRawValue: defaultModifiers, additionalDisplayModifiersRawValue: displayModifier)
            case 3:
                return ShortcutBinding(keyCode: UInt16(kVK_ANSI_4), modifiersRawValue: defaultModifiers, additionalDisplayModifiersRawValue: displayModifier)
            case 4:
                return ShortcutBinding(keyCode: UInt16(kVK_ANSI_5), modifiersRawValue: defaultModifiers, additionalDisplayModifiersRawValue: displayModifier)
            case 5:
                return ShortcutBinding(keyCode: UInt16(kVK_ANSI_6), modifiersRawValue: defaultModifiers, additionalDisplayModifiersRawValue: displayModifier)
            case 6:
                return ShortcutBinding(keyCode: UInt16(kVK_ANSI_7), modifiersRawValue: defaultModifiers, additionalDisplayModifiersRawValue: displayModifier)
            case 7:
                return ShortcutBinding(keyCode: UInt16(kVK_ANSI_8), modifiersRawValue: defaultModifiers, additionalDisplayModifiersRawValue: displayModifier)
            case 8:
                return ShortcutBinding(keyCode: UInt16(kVK_ANSI_9), modifiersRawValue: defaultModifiers, additionalDisplayModifiersRawValue: displayModifier)
            default:
                return nil
            }
        case let .traverse(direction):
            switch direction {
            case .left:
                return ShortcutBinding(keyCode: UInt16(kVK_LeftArrow), modifiersRawValue: defaultModifiers)
            case .right:
                return ShortcutBinding(keyCode: UInt16(kVK_RightArrow), modifiersRawValue: defaultModifiers)
            case .up:
                return ShortcutBinding(keyCode: UInt16(kVK_UpArrow), modifiersRawValue: defaultModifiers)
            case .down:
                return ShortcutBinding(keyCode: UInt16(kVK_DownArrow), modifiersRawValue: defaultModifiers)
            }
        case .maximize:
            return ShortcutBinding(keyCode: UInt16(kVK_ANSI_M), modifiersRawValue: defaultModifiers)
        case .moveToNextDisplay:
            return ShortcutBinding(keyCode: UInt16(kVK_ANSI_N), modifiersRawValue: defaultModifiers)
        case .moveToNextDisplayPreservingTile:
            return ShortcutBinding(keyCode: UInt16(kVK_ANSI_P), modifiersRawValue: defaultModifiers)
        case .leftHalf:
            return nil
        case .rightHalf:
            return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .moveToTile:
            self = .moveToTile(index: try container.decode(Int.self, forKey: .index))
        case .traverse:
            self = .traverse(direction: try container.decode(TileTraversalDirection.self, forKey: .direction))
        case .maximize:
            self = .maximize
        case .moveToNextDisplay:
            self = .moveToNextDisplay
        case .moveToNextDisplayPreservingTile:
            self = .moveToNextDisplayPreservingTile
        case .leftHalf:
            self = .leftHalf
        case .rightHalf:
            self = .rightHalf
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .moveToTile(index):
            try container.encode(Kind.moveToTile, forKey: .kind)
            try container.encode(index, forKey: .index)
        case let .traverse(direction):
            try container.encode(Kind.traverse, forKey: .kind)
            try container.encode(direction, forKey: .direction)
        case .maximize:
            try container.encode(Kind.maximize, forKey: .kind)
        case .moveToNextDisplay:
            try container.encode(Kind.moveToNextDisplay, forKey: .kind)
        case .moveToNextDisplayPreservingTile:
            try container.encode(Kind.moveToNextDisplayPreservingTile, forKey: .kind)
        case .leftHalf:
            try container.encode(Kind.leftHalf, forKey: .kind)
        case .rightHalf:
            try container.encode(Kind.rightHalf, forKey: .kind)
        }
    }
}
