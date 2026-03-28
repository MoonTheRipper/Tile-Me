import CoreGraphics
import Foundation

enum SplitAxis: String, Codable, Equatable, Sendable {
    case horizontal
    case vertical
}

struct TileChild: Codable, Equatable, Sendable {
    var fraction: Double
    var node: TileNode

    init(fraction: Double, node: TileNode) {
        self.fraction = fraction
        self.node = node
    }
}

indirect enum TileNode: Codable, Equatable, Sendable {
    case leaf(id: String)
    case split(id: String, axis: SplitAxis, children: [TileChild])

    private enum CodingKeys: String, CodingKey {
        case kind
        case id
        case axis
        case children
    }

    private enum Kind: String, Codable {
        case leaf
        case split
    }

    var id: String {
        switch self {
        case let .leaf(id):
            return id
        case let .split(id, _, _):
            return id
        }
    }

    var leafCount: Int {
        switch self {
        case let .leaf(id):
            return id.isEmpty ? 0 : 1
        case let .split(_, _, children):
            return children.reduce(0) { $0 + $1.node.leafCount }
        }
    }

    var orderedLeafIDs: [String] {
        switch self {
        case let .leaf(id):
            return [id]
        case let .split(_, _, children):
            return children.flatMap(\.node.orderedLeafIDs)
        }
    }

    var orderedNodeIDs: [String] {
        switch self {
        case let .leaf(id):
            return [id]
        case let .split(id, _, children):
            return [id] + children.flatMap(\.node.orderedNodeIDs)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .leaf:
            self = .leaf(id: try container.decode(String.self, forKey: .id))
        case .split:
            self = .split(
                id: try container.decode(String.self, forKey: .id),
                axis: try container.decode(SplitAxis.self, forKey: .axis),
                children: try container.decode([TileChild].self, forKey: .children)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .leaf(id):
            try container.encode(Kind.leaf, forKey: .kind)
            try container.encode(id, forKey: .id)
        case let .split(id, axis, children):
            try container.encode(Kind.split, forKey: .kind)
            try container.encode(id, forKey: .id)
            try container.encode(axis, forKey: .axis)
            try container.encode(children, forKey: .children)
        }
    }
}

struct LayoutDefinition: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var name: String
    var root: TileNode

    var tileCount: Int {
        root.leafCount
    }

    var tileIDs: [String] {
        root.orderedLeafIDs
    }
}

struct TileFrame: Identifiable, Equatable, Sendable {
    let tileID: String
    let index: Int
    let frame: CGRect

    var id: String {
        tileID
    }
}
