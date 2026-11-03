import SwiftUI

/// Cores derivadas da cor do jogador (camisa, calça, contorno, cabelo), como na TV.
struct AvatarPalette {
    let base: Color
    private let rgb: (r: Double, g: Double, b: Double)

    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
        rgb = (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
        base = Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    func shade(_ factor: Double) -> Color {
        Color(red: min(1, rgb.r * factor), green: min(1, rgb.g * factor), blue: min(1, rgb.b * factor))
    }

    /// Mistura com branco (`amount` de 0 a 1).
    func tint(_ amount: Double) -> Color {
        Color(red: rgb.r + (1 - rgb.r) * amount, green: rgb.g + (1 - rgb.g) * amount, blue: rgb.b + (1 - rgb.b) * amount)
    }

    var shirtEdge: Color { shade(0.42) }
    var pants: Color { shade(0.55) }
    var pantsEdge: Color { shade(0.3) }
    var hair: Color { shade(0.42) }

    static let skin = Color(hex: "#FFD9B8")
    static let skinEdge = Color(hex: "#B97F5C")
    static let ink = Color(hex: "#2B2140")
}
