import FluidAudio
import Foundation
import Observation

/// Whether the transcription model is on the phone yet, for Settings and the meeting screen.
@MainActor
@Observable
final class SpeechModelStatus {
    static let shared = SpeechModelStatus()

    enum State: Equatable {
        case notDownloaded
        case downloading(Double)
        case ready
        case failed(String)
    }

    var state: State

    private init() {
        let directory = AsrModels.defaultCacheDirectory(for: .v2)
        state = AsrModels.modelsExist(at: directory, version: .v2) ? .ready : .notDownloaded
    }
}

/// On-device transcription with NVIDIA's Parakeet TDT 0.6B v2 (English), run through FluidAudio.
///
/// Chosen over Apple's SpeechAnalyzer after a side-by-side on real classroom recordings: with a
/// lecturer about 10 m away, Apple caught a dozen words in five minutes, Whisper large-v3 turbo looped
/// on repeated sentences, and Parakeet got the lecture. The model downloads once (a few hundred MB).
actor ParakeetTranscriber: Transcribing {
    static let shared = ParakeetTranscriber()

    private static let version: AsrModelVersion = .v2
    private var manager: AsrManager?

    /// Downloads and loads the model ahead of time (from Settings), so the first meeting doesn't wait.
    func prepare() async throws {
        _ = try await loadedManager()
    }

    func transcribe(fileAt url: URL) async throws -> Transcription {
        let manager = try await loadedManager()
        var state = TdtDecoderState.make(decoderLayers: Self.version.decoderLayers)
        let result = try await manager.transcribe(url, decoderState: &state)

        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TranscriberError.noSpeech }
        return Transcription(text: text, words: Self.words(from: result.tokenTimings ?? []))
    }

    private func loadedManager() async throws -> AsrManager {
        if let manager { return manager }
        do {
            let models = try await AsrModels.downloadAndLoad(version: Self.version) { progress in
                Task { @MainActor in
                    SpeechModelStatus.shared.state = .downloading(progress.fractionCompleted)
                }
            }
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            self.manager = manager
            await MainActor.run { SpeechModelStatus.shared.state = .ready }
            return manager
        } catch {
            await MainActor.run { SpeechModelStatus.shared.state = .failed(error.localizedDescription) }
            throw error
        }
    }

    /// Joins sub-word tokens into words. A token starting with a space (or SentencePiece's "▁") begins a word.
    private static func words(from tokens: [TokenTiming]) -> [TimedWord] {
        var words: [TimedWord] = []
        for token in tokens {
            let piece = token.token.replacingOccurrences(of: "\u{2581}", with: " ")
            if piece.hasPrefix(" ") || words.isEmpty {
                words.append(TimedWord(text: piece, start: token.startTime, end: token.endTime))
            } else if let last = words.popLast() {
                words.append(TimedWord(text: last.text + piece, start: last.start, end: token.endTime))
            }
        }
        return words
    }
}
