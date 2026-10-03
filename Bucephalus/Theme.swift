import SwiftUI

enum Theme {
    static let accent = Color(red: 0.93, green: 0.36, blue: 0.24)
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
