import SwiftUI

// MARK: - Color from hex

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (r, g, b) = (value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF)
        case 3:
            (r, g, b) = ((value >> 8 & 0xF) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17)
        default:
            (r, g, b) = (79, 142, 247) // fallback blue
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: 1)
    }
}

// MARK: - Project color palette

enum ProjectPalette {
    static let hexes: [String] = [
        "#4F8EF7", // blue
        "#E8643A", // orange
        "#34C759", // green
        "#AF52DE", // purple
        "#FF375F", // pink
        "#FFCC00", // yellow
        "#5AC8FA", // teal
        "#8E8E93"  // gray
    ]
}

// MARK: - Duration formatting

enum TimeFormat {
    /// "1:05:09" when there are hours, otherwise "05:09".
    static func hms(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    /// Compact: "2h 05m" or "12m".
    static func hm(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let h = total / 3600, m = (total % 3600) / 60
        return h > 0 ? String(format: "%dh %02dm", h, m) : String(format: "%dm", m)
    }
}
