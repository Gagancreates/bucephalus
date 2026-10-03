import AVFoundation
import Speech

protocol Transcribing {
    func transcribe(fileAt url: URL) async throws -> String
}

/// On-device transcription with Apple's SpeechAnalyzer.
struct AppleTranscriber: Transcribing {
    func transcribe(fileAt url: URL) async throws -> String {
        guard SpeechTranscriber.isAvailable else { throw TranscriberError.unavailable }

        let locale = await Self.bestLocale()
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )

        // First use downloads the language model; after that it's fully offline.
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let file = try AVAudioFile(forReading: url)

        async let collected = transcriber.results.reduce(into: "") { text, result in
            text += String(result.text.characters)
        }

        if let lastSample = try await analyzer.analyzeSequence(from: file) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            await analyzer.cancelAndFinishNow()
        }

        let text = try await collected.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriberError.noSpeech }
        return text
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
