import Foundation

enum BuiltinLayouts {
    static let halves = LayoutDefinition(
        id: "halves",
        name: "Halves",
        root: .split(
            id: "halves-root",
            axis: .vertical,
            children: [
                TileChild(fraction: 1, node: .leaf(id: "halves-left")),
                TileChild(fraction: 1, node: .leaf(id: "halves-right")),
            ]
        )
    )

    static let grid2x2 = grid(id: "grid-2x2", name: "2x2", rows: 2, columns: 2)
    static let grid3x3 = grid(id: "grid-3x3", name: "3x3", rows: 3, columns: 3)
    static let grid4x4 = grid(id: "grid-4x4", name: "4x4", rows: 4, columns: 4)

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

    static let all = [halves, grid2x2, grid3x3, grid4x4]
    static let nestedExamples = [topPairBottomWide, largeLeftStackedRight]

    static var defaultLayout: LayoutDefinition {
        halves
    }

    static func definition(id: String) -> LayoutDefinition? {
        (all + nestedExamples).first { $0.id == id }
    }

    static func grid(id: String, name: String, rows: Int, columns: Int) -> LayoutDefinition {
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
}
