import SwiftUI

enum Theme {
    /// Dark maroon, a shade lighter in dark mode so it doesn't sink into black.
    static let accent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.56, green: 0.12, blue: 0.21, alpha: 1)
            : UIColor(red: 0.45, green: 0.09, blue: 0.17, alpha: 1)
    })
    /// Foreground for anything drawn on top of `accent`.
    static let onAccent = Color.white
    /// The only colour in the app, reserved for the live recording indicator.
    static let recording = Color(red: 0.92, green: 0.26, blue: 0.24)
    /// Background for content cards.
    static let card = Color(.secondarySystemBackground)
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
