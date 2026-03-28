import CoreGraphics
import Foundation

struct DisplayProfile: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var name: String
    var frame: CGRect
    var visibleFrame: CGRect
    var scale: CGFloat
    var isBuiltIn: Bool

    var frameSizeDescription: String {
        Self.sizeDescription(for: frame.size)
    }

    var visibleFrameSizeDescription: String {
        Self.sizeDescription(for: visibleFrame.size)
    }

    var scaleDescription: String {
        let roundedScale = scale.rounded()
        if roundedScale == scale {
            return "\(Int(roundedScale))x"
        }

        return String(format: "%.1fx", Double(scale))
    }

    var typeDescription: String {
        isBuiltIn ? "Built-in" : "External"
    }

    private static func sizeDescription(for size: CGSize) -> String {
        "\(Int(size.width.rounded())) x \(Int(size.height.rounded()))"
    }
}
