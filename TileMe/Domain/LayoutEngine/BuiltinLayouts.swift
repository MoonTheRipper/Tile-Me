import Foundation

struct BuiltinLayoutGroup: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let layouts: [LayoutDefinition]
}

struct BuiltinLayoutSection: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let layouts: [LayoutDefinition]
    let groups: [BuiltinLayoutGroup]
}

enum BuiltinLayouts {
    static let halves1x2 = halves(
        id: "halves-1x2",
        name: "1x2",
        axis: .horizontal,
        firstTileID: "halves-top",
        secondTileID: "halves-bottom"
    )

    static let halves2x1 = halves(
        id: "halves",
        name: "2x1",
        axis: .vertical,
        firstTileID: "halves-left",
        secondTileID: "halves-right"
    )

    static let halves = halves2x1

    static let grid2x2 = gridPreset(columns: 2, rows: 2)
    static let grid3x3 = gridPreset(columns: 3, rows: 3)
    static let grid4x4 = gridPreset(columns: 4, rows: 4)
    static let gridPresetsByColumns: [Int: [LayoutDefinition]] = Dictionary(
        uniqueKeysWithValues: (2...5).map { columns in
            (columns, (2...5).map { rows in gridPreset(columns: columns, rows: rows) })
        }
    )
    static let gridPresets = (2...5).flatMap { gridPresetsByColumns[$0] ?? [] }

    static let topPairBottomWide = LayoutDefinition(
        id: "nested-top-pair-bottom-wide",
        name: "Top Pair + Bottom Wide",
        root: .split(
            id: "nested-top-pair-bottom-wide-root",
            axis: .horizontal,
            children: [
                TileChild(
                    fraction: 2,
                    node: .split(
                        id: "nested-top-pair-bottom-wide-top-row",
                        axis: .vertical,
                        children: [
                            TileChild(fraction: 1, node: .leaf(id: "nested-top-pair-bottom-wide-top-left")),
                            TileChild(fraction: 1, node: .leaf(id: "nested-top-pair-bottom-wide-top-right")),
                        ]
                    )
                ),
                TileChild(fraction: 1, node: .leaf(id: "nested-top-pair-bottom-wide-bottom")),
            ]
        )
    )

    static let largeLeftStackedRight = LayoutDefinition(
        id: "nested-large-left-stacked-right",
        name: "Large Left + Stacked Right",
        root: .split(
            id: "nested-large-left-stacked-right-root",
            axis: .vertical,
            children: [
                TileChild(fraction: 3, node: .leaf(id: "nested-large-left-stacked-right-left")),
                TileChild(
                    fraction: 2,
                    node: .split(
                        id: "nested-large-left-stacked-right-right-stack",
                        axis: .horizontal,
                        children: [
                            TileChild(fraction: 1, node: .leaf(id: "nested-large-left-stacked-right-top")),
                            TileChild(fraction: 1, node: .leaf(id: "nested-large-left-stacked-right-bottom")),
                        ]
                    )
                ),
            ]
        )
    )

    static let all = [halves1x2, halves2x1] + gridPresets
    static let nestedExamples = [topPairBottomWide, largeLeftStackedRight]
    static let presetSections = [
        BuiltinLayoutSection(
            id: "halves",
            title: "Halves",
            layouts: [halves1x2, halves2x1],
            groups: []
        ),
        BuiltinLayoutSection(
            id: "grid-presets",
            title: "Grid Presets",
            layouts: [],
            groups: (2...5).map { columns in
                BuiltinLayoutGroup(
                    id: "grid-presets-\(columns)-columns",
                    title: "\(columns) Columns",
                    layouts: gridPresetsByColumns[columns] ?? []
                )
            }
        ),
    ]

    static var defaultLayout: LayoutDefinition {
        halves
    }

    static func definition(id: String) -> LayoutDefinition? {
        (all + nestedExamples).first { $0.id == id }
    }

    static func gridPreset(columns: Int, rows: Int) -> LayoutDefinition {
        grid(
            id: "grid-\(columns)x\(rows)",
            name: "\(columns)x\(rows)",
            columns: columns,
            rows: rows
        )
    }

    static func grid(id: String, name: String, columns: Int, rows: Int) -> LayoutDefinition {
        precondition(rows > 0 && columns > 0, "Grid dimensions must be greater than zero")

        let rowChildren = (1...rows).map { row in
            let columnChildren = (1...columns).map { column in
                TileChild(
                    fraction: 1,
                    node: .leaf(id: "\(id)-r\(row)-c\(column)")
                )
            }

            return TileChild(
                fraction: 1,
                node: .split(id: "\(id)-row-\(row)", axis: .vertical, children: columnChildren)
            )
        }

        return LayoutDefinition(
            id: id,
            name: name,
            root: .split(id: "\(id)-root", axis: .horizontal, children: rowChildren)
        )
    }

    private static func halves(
        id: String,
        name: String,
        axis: SplitAxis,
        firstTileID: String,
        secondTileID: String
    ) -> LayoutDefinition {
        LayoutDefinition(
            id: id,
            name: name,
            root: .split(
                id: "\(id)-root",
                axis: axis,
                children: [
                    TileChild(fraction: 1, node: .leaf(id: firstTileID)),
                    TileChild(fraction: 1, node: .leaf(id: secondTileID)),
                ]
            )
        )
    }
}
