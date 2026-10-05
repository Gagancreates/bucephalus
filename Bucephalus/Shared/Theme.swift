import SwiftUI

enum Theme {
    /// The accent chosen in Settings (dark maroon unless changed).
    static var accent: Color { AccentChoice.current.color }
    /// Distinct, muted colours for speakers, in the order they first speak.
    static func speakerColor(_ order: Int) -> Color {
        let palette: [Color] = [
            // A lighter maroon than `accent`, which is too dark to read as text on a dark card.
            Color(red: 0.80, green: 0.32, blue: 0.40),
            Color(red: 0.27, green: 0.45, blue: 0.70),
            Color(red: 0.20, green: 0.55, blue: 0.48),
            Color(red: 0.78, green: 0.52, blue: 0.18),
            Color(red: 0.52, green: 0.36, blue: 0.68),
            Color(red: 0.45, green: 0.52, blue: 0.25),
        ]
        return palette[order % palette.count]
    }
    /// Foreground for anything drawn on top of `accent`.
    static let onAccent = Color.white
    /// The only colour in the app, reserved for the live recording indicator.
    static let recording = Color(red: 0.92, green: 0.26, blue: 0.24)
    /// Background for content cards.
    static let card = Color(.secondarySystemBackground)
}

enum AccentChoice: String, CaseIterable, Identifiable {
    case maroon, ink, forest, graphite

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    static let storageKey = "accent"

    /// The widget extension can't read the app's settings, so it always falls back to maroon.
    static var current: AccentChoice {
        AccentChoice(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .maroon
    }

    /// Each accent is a shade lighter in dark mode so it doesn't sink into black.
    var color: Color {
        let (light, dark): ((Double, Double, Double), (Double, Double, Double)) = switch self {
        case .maroon: ((0.45, 0.09, 0.17), (0.56, 0.12, 0.21))
        case .ink: ((0.13, 0.20, 0.42), (0.32, 0.42, 0.72))
        case .forest: ((0.11, 0.33, 0.25), (0.22, 0.52, 0.40))
        case .graphite: ((0.20, 0.21, 0.23), (0.62, 0.63, 0.66))
        }
        return Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

extension TimeInterval {
    /// "1:02:07" or "04:31", for the live recording timer.
    var clockString: String {
        let total = Int(self)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    /// "42 min" or "1 hr 5 min", for lists.
    var shortDurationString: String {
        let minutes = max(1, Int((self / 60).rounded()))
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }
}
