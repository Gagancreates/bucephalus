import FluidAudio
import Foundation

/// A stretch of the recording where one speaker is talking.
struct SpeakerTurn: Sendable {
    let speaker: Int
    let start: Double
    let end: Double
}

/// Works out who spoke when, on this iPhone, with FluidAudio's offline diarizer.
/// The models download once (a few tens of MB) and run on the Neural Engine after that.
enum SpeakerDiarizer {
    static func turns(inFileAt url: URL) async throws -> [SpeakerTurn] {
        let manager = OfflineDiarizerManager()
        try await manager.prepareModels()
        let result = try await manager.process(url)

        // Number speakers 1, 2, 3… in the order they first speak.
        var numbers: [String: Int] = [:]
        return result.segments
            .sorted { $0.startTimeSeconds < $1.startTimeSeconds }
            .map { segment in
                let number = numbers[segment.speakerId] ?? (numbers.count + 1)
                numbers[segment.speakerId] = number
                return SpeakerTurn(
                    speaker: number,
                    start: Double(segment.startTimeSeconds),
                    end: Double(segment.endTimeSeconds)
                )
            }
    }
}

/// Joins word timings with speaker turns into readable transcript segments.
enum TranscriptBuilder {
    /// A pause this long starts a new paragraph even when the speaker doesn't change.
    private static let paragraphPause = 2.0

    static func segments(words: [TimedWord], turns: [SpeakerTurn]) -> [TranscriptSegment] {
        var segments: [TranscriptSegment] = []
        var lastEnd = 0.0

        for word in words {
            let isSpacing = word.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let speaker = turns.isEmpty ? nil : speaker(at: (word.start + word.end) / 2, in: turns)

            if var current = segments.last,
               isSpacing || (current.speaker == speaker && word.start - lastEnd < paragraphPause) {
                current.text += word.text
                segments[segments.count - 1] = current
            } else {
                segments.append(TranscriptSegment(speaker: speaker, start: word.start, text: word.text))
            }
            if !isSpacing { lastEnd = word.end }
        }

        return smoothed(segments)
            .map { TranscriptSegment(speaker: $0.speaker, start: $0.start, text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.text.isEmpty }
    }

    private static func speaker(at time: Double, in turns: [SpeakerTurn]) -> Int? {
        if let turn = turns.first(where: { $0.start <= time && time <= $0.end }) {
            return turn.speaker
        }
        // In a gap between turns: whoever was closest.
        return turns.min { distance(time, $0) < distance(time, $1) }?.speaker
    }

    private static func distance(_ time: Double, _ turn: SpeakerTurn) -> Double {
        time < turn.start ? turn.start - time : time - turn.end
    }

    /// A single stray word assigned to another speaker is almost always a diarization blip; fold it back.
    private static func smoothed(_ segments: [TranscriptSegment]) -> [TranscriptSegment] {
        var result: [TranscriptSegment] = []
        for segment in segments {
            let wordCount = segment.text.split(whereSeparator: \.isWhitespace).count
            if wordCount <= 1, var previous = result.last, previous.speaker != segment.speaker {
                previous.text += " " + segment.text.trimmingCharacters(in: .whitespaces)
                result[result.count - 1] = previous
            } else {
                result.append(segment)
            }
        }
        return result
    }
}
