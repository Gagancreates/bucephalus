import ActivityKit
import AppIntents
import Foundation

/// The Live Activity shown on the lock screen and in the Dynamic Island while recording.
struct RecordingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Now minus the time recorded so far, so the timer can count up on its own.
        var startedAt: Date
        /// Set while paused; the timer freezes at this moment.
        var pausedAt: Date?
        var isPaused: Bool { pausedAt != nil }
    }
}

/// Bridges intents (compiled into the app and the widget extension) to the app's recorder.
/// The system runs these intents in the app's process, where the app sets the handlers at launch.
enum RecordingIntentHandler {
    @MainActor static var start: (@MainActor () async throws -> Void)?
    @MainActor static var stop: (@MainActor () async -> Void)?
    @MainActor static var togglePause: (@MainActor () async -> Void)?
    @MainActor static var toggle: (@MainActor () async throws -> Void)?
}

/// Starts recording without unlocking the phone or opening the app.
struct StartRecordingIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Start Recording"
    static let description = IntentDescription("Starts recording a conversation in Bucephalus.")

    func perform() async throws -> some IntentResult {
        guard let start = await RecordingIntentHandler.start else { return .result() }
        try await start()
        return .result()
    }
}

struct StopRecordingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Recording"
    static let description = IntentDescription("Stops the current recording and starts transcribing it.")

    func perform() async throws -> some IntentResult {
        guard let stop = await RecordingIntentHandler.stop else { return .result() }
        await stop()
        return .result()
    }
}

struct TogglePauseRecordingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or Resume Recording"
    static let description = IntentDescription("Pauses the current recording, or resumes it if it's paused.")

    func perform() async throws -> some IntentResult {
        guard let togglePause = await RecordingIntentHandler.togglePause else { return .result() }
        await togglePause()
        return .result()
    }
}

/// One button that starts a recording, or stops the one in progress. Made for the Action Button.
struct ToggleRecordingIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Record or Stop"
    static let description = IntentDescription("Starts recording a conversation in Bucephalus, or stops the current recording.")

    func perform() async throws -> some IntentResult {
        guard let toggle = await RecordingIntentHandler.toggle else { return .result() }
        try await toggle()
        return .result()
    }
}
