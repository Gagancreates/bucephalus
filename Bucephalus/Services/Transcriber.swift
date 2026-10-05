import AVFoundation
import Speech

/// A word (or the space and punctuation around it) with where it falls in the recording.
struct TimedWord: Sendable {
    let text: String
    let start: Double
    let end: Double
}

struct Transcription: Sendable {
    let text: String
    let words: [TimedWord]
}

protocol Transcribing {
    func transcribe(fileAt url: URL) async throws -> Transcription
}

/// On-device transcription with Apple's SpeechAnalyzer.
struct AppleTranscriber: Transcribing {
    func transcribe(fileAt url: URL) async throws -> Transcription {
        guard SpeechTranscriber.isAvailable else { throw TranscriberError.unavailable }

        let locale = await Self.bestLocale()
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            // Word timings, so each word can be matched to whoever was speaking at that moment.
            attributeOptions: [.audioTimeRange]
        )

        // First use downloads the language model; after that it's fully offline.
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let file = try AVAudioFile(forReading: url)

        async let collected = transcriber.results.reduce(into: [TimedWord]()) { words, result in
            let phraseStart = result.range.start.seconds
            let phraseEnd = result.range.end.seconds
            for run in result.text.runs {
                let text = String(result.text[run.range].characters)
                if let range = run[AttributeScopes.SpeechAttributes.TimeRangeAttribute.self] {
                    words.append(TimedWord(text: text, start: range.start.seconds, end: range.end.seconds))
                } else {
                    // Spaces and punctuation carry no timing; give them their neighbour's.
                    let at = words.last?.end ?? phraseStart
                    words.append(TimedWord(text: text, start: at, end: min(at, phraseEnd)))
                }
            }
        }

        if let lastSample = try await analyzer.analyzeSequence(from: file) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            await analyzer.cancelAndFinishNow()
        }

        let words = try await collected
        let text = words.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriberError.noSpeech }
        return Transcription(text: text, words: words)
    }

    private static func bestLocale() async -> Locale {
        let supported = await SpeechTranscriber.supportedLocales
        let current = Locale.current.identifier(.bcp47)
        if let match = supported.first(where: { $0.identifier(.bcp47) == current }) {
            return match
        }
        return Locale(identifier: "en-US")
    }
}

enum TranscriberError: LocalizedError {
    case unavailable, noSpeech

    var errorDescription: String? {
        switch self {
        case .unavailable: "On-device transcription isn't available on this device."
        case .noSpeech: "No speech was found in this recording."
        }
    }
}
