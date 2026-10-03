import AVFoundation
import Observation
import UIKit

/// Runs a finished recording through transcription, then summarisation.
@MainActor
@Observable
final class MeetingProcessor {
    private var inFlight: Set<UUID> = []
    private let transcriber: Transcribing = AppleTranscriber()

    func enqueue(_ meeting: Meeting) {
        guard !inFlight.contains(meeting.id) else { return }
        inFlight.insert(meeting.id)
        Task {
            // Buys a little time to finish if the phone is locked right after stopping.
            let background = UIApplication.shared.beginBackgroundTask()
            await process(meeting)
            inFlight.remove(meeting.id)
            UIApplication.shared.endBackgroundTask(background)
        }
    }

    private func process(_ meeting: Meeting) async {
        meeting.errorMessage = nil
        do {
            if meeting.duration == 0, let file = try? AVAudioFile(forReading: meeting.audioURL) {
                meeting.duration = Double(file.length) / file.fileFormat.sampleRate
            }

            if meeting.transcript == nil {
                meeting.status = .transcribing
                save(meeting)
                meeting.transcript = try await transcriber.transcribe(fileAt: meeting.audioURL)
            }

            meeting.status = .summarizing
            save(meeting)
            let provider = Provider.current
            guard let key = Keychain.read(provider.keychainAccount), !key.isEmpty else {
                throw LLMError.missingKey(provider)
            }
            let client = LLMClient(provider: provider, apiKey: key)
            let summary = try await Summarizer(client: client, model: provider.selectedModel)
                .summarize(transcript: meeting.transcript ?? "")
            meeting.summary = summary
            let autoTitle = UserDefaults.standard.object(forKey: SettingsKeys.autoTitle) as? Bool ?? true
            // Never overwrite a name the user typed.
            if autoTitle, !summary.title.isEmpty, meeting.title == Meeting.defaultTitle {
                meeting.title = summary.title
            }
            meeting.status = .done
        } catch {
            meeting.status = .failed
            meeting.errorMessage = error.localizedDescription
        }
        save(meeting)
    }

    private func save(_ meeting: Meeting) {
        try? meeting.modelContext?.save()
    }
}
