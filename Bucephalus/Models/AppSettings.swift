import SwiftUI

/// UserDefaults keys and choices for everything in Settings that isn't an API key.
enum AppSettings {
    static let appearance = "appearance"
    static let accent = AccentChoice.storageKey
    static let audioQuality = "audioQuality"
    static let keepAudio = "keepAudio"
    static let summaryStyle = "summaryStyle"
    static let customInstructions = "customInstructions"

    static var keepsAudio: Bool { UserDefaults.standard.object(forKey: keepAudio) as? Bool ?? true }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AudioQuality: String, CaseIterable, Identifiable {
    case standard, high

    var id: String { rawValue }
    var name: String { self == .standard ? "Standard" : "High" }
    var detail: String { self == .standard ? "About 30 MB an hour" : "About 60 MB an hour" }
    var bitRate: Int { self == .standard ? 64_000 : 128_000 }

    static var current: AudioQuality {
        AudioQuality(rawValue: UserDefaults.standard.string(forKey: AppSettings.audioQuality) ?? "") ?? .standard
    }
}

enum SummaryStyle: String, CaseIterable, Identifiable {
    case standard, brief, detailed, custom

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    static var current: SummaryStyle {
        SummaryStyle(rawValue: UserDefaults.standard.string(forKey: AppSettings.summaryStyle) ?? "") ?? .standard
    }

    /// Extra guidance appended to the summary prompt.
    var instructions: String? {
        switch self {
        case .standard:
            return nil
        case .brief:
            return "Keep it short: a one-sentence overview and at most four key points."
        case .detailed:
            return "Be thorough: a fuller overview and up to ten key points, keeping numbers, dates and names."
        case .custom:
            let text = UserDefaults.standard.string(forKey: AppSettings.customInstructions)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return text.isEmpty ? nil : "Follow these instructions from the user: \(text)"
        }
    }
}
