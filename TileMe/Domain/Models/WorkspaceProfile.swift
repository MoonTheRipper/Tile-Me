import Foundation

struct DisplayLayoutAssignment: Codable, Equatable, Sendable {
    enum Mode: String, CaseIterable, Codable, Identifiable, Sendable {
        case ownLayout
        case copiedLayout
        case mirroredDisplay

        var id: String {
            rawValue
        }
    }

    enum Source: Codable, Equatable, Sendable {
        case layout(id: String)
        case copied(displayID: String, layoutID: String)
        case mirrored(displayID: String)

        private enum CodingKeys: String, CodingKey {
            case kind
            case id
            case displayID
            case layoutID
        }

        private enum Kind: String, Codable {
            case layout
            case copied
            case mirrored
            case reuse
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(Kind.self, forKey: .kind) {
            case .layout:
                self = .layout(id: try container.decode(String.self, forKey: .id))
            case .copied:
                self = .copied(
                    displayID: try container.decode(String.self, forKey: .displayID),
                    layoutID: try container.decode(String.self, forKey: .layoutID)
                )
            case .mirrored, .reuse:
                self = .mirrored(displayID: try container.decode(String.self, forKey: .displayID))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .layout(id):
                try container.encode(Kind.layout, forKey: .kind)
                try container.encode(id, forKey: .id)
            case let .copied(displayID, layoutID):
                try container.encode(Kind.copied, forKey: .kind)
                try container.encode(displayID, forKey: .displayID)
                try container.encode(layoutID, forKey: .layoutID)
            case let .mirrored(displayID):
                try container.encode(Kind.mirrored, forKey: .kind)
                try container.encode(displayID, forKey: .displayID)
            }
        }
    }

    var source: Source

    var mode: Mode {
        switch source {
        case .layout:
            return .ownLayout
        case .copied:
            return .copiedLayout
        case .mirrored:
            return .mirroredDisplay
        }
    }

    var sourceDisplayID: String? {
        switch source {
        case .layout:
            return nil
        case let .copied(displayID, _), let .mirrored(displayID):
            return displayID
        }
    }

    var directLayoutID: String? {
        switch source {
        case let .layout(id):
            return id
        case let .copied(_, layoutID):
            return layoutID
        case .mirrored:
            return nil
        }
    }
}

struct WorkspaceProfile: Codable, Equatable, Sendable {
    static let defaultLayoutID = "halves"

    var displayAssignments: [String: DisplayLayoutAssignment]
    var shortcuts: [String: ShortcutBinding]

    init(
        displayAssignments: [String: DisplayLayoutAssignment] = [:],
        shortcuts: [String: ShortcutBinding] = ShortcutAction.defaultBindings
    ) {
        self.displayAssignments = displayAssignments
        self.shortcuts = shortcuts
    }

    func assignment(for displayID: String) -> DisplayLayoutAssignment? {
        displayAssignments[displayID]
    }

    func shortcut(for action: ShortcutAction) -> ShortcutBinding? {
        shortcuts[action.id]
    }

    mutating func setLayout(id: String, for displayID: String) {
        displayAssignments[displayID] = DisplayLayoutAssignment(source: .layout(id: id))
    }

    mutating func copyLayout(
        from sourceDisplayID: String,
        for displayID: String,
        fallback fallbackLayoutID: String = defaultLayoutID
    ) {
        let layoutID = resolvedLayoutID(for: sourceDisplayID, fallback: fallbackLayoutID)
        displayAssignments[displayID] = DisplayLayoutAssignment(
            source: .copied(displayID: sourceDisplayID, layoutID: layoutID)
        )
    }

    mutating func mirrorLayout(from sourceDisplayID: String, for displayID: String) {
        displayAssignments[displayID] = DisplayLayoutAssignment(source: .mirrored(displayID: sourceDisplayID))
    }

    mutating func promoteResolvedLayoutToOwn(
        for displayID: String,
        fallback fallbackLayoutID: String = defaultLayoutID
    ) {
        setLayout(id: resolvedLayoutID(for: displayID, fallback: fallbackLayoutID), for: displayID)
    }

    mutating func removeAssignment(for displayID: String) {
        displayAssignments.removeValue(forKey: displayID)
    }

    mutating func setShortcut(_ descriptor: ShortcutBinding?, for action: ShortcutAction) {
        if let descriptor {
            shortcuts[action.id] = descriptor
        } else {
            shortcuts.removeValue(forKey: action.id)
        }
    }

    func resolvedLayoutID(for displayID: String, fallback fallbackLayoutID: String = defaultLayoutID) -> String {
        var visited = Set<String>()
        var currentDisplayID = displayID

        while true {
            guard visited.insert(currentDisplayID).inserted else {
                return fallbackLayoutID
            }

            guard let assignment = displayAssignments[currentDisplayID] else {
                return fallbackLayoutID
            }

            switch assignment.source {
            case let .layout(id):
                return id
            case let .copied(_, layoutID):
                return layoutID
            case let .mirrored(nextDisplayID):
                currentDisplayID = nextDisplayID
            }
        }
    }

    func directLayoutID(for displayID: String) -> String? {
        assignment(for: displayID)?.directLayoutID
    }

    func mode(for displayID: String) -> DisplayLayoutAssignment.Mode {
        assignment(for: displayID)?.mode ?? .ownLayout
    }

    func sourceDisplayID(for displayID: String) -> String? {
        assignment(for: displayID)?.sourceDisplayID
    }
}
