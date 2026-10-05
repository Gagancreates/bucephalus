import Foundation
import SwiftData

enum MeetingStatus: String {
    case recording, transcribing, diarizing, summarizing, done, failed

    var isInProgress: Bool { [.recording, .transcribing, .diarizing, .summarizing].contains(self) }

    var progressLabel: String {
        switch self {
        case .recording: "Recording"
        case .diarizing: "Identifying speakers"
        case .summarizing: "Summarising"
        default: "Transcribing"
        }
    }
}

struct MeetingSummary: Codable {
    var title: String
    var overview: String
    var keyPoints: [String]
    var decisions: [String]
    var actionItems: [String]
}

/// A stretch of the transcript said by one speaker (or one paragraph, when speakers aren't known).
struct TranscriptSegment: Codable, Hashable {
    /// 1-based speaker number, or nil when speakers couldn't be identified.
    var speaker: Int?
    /// Seconds from the start of the recording.
    var start: Double
    var text: String
}

/// The current stored shape of a meeting. See `Storage.swift` before changing any stored property.
typealias Meeting = SchemaV2.Meeting

extension SchemaV2 {
    @Model
    final class Meeting {
        static let defaultTitle = "New meeting"

        var id: UUID
        var title: String
        var createdAt: Date
        var duration: TimeInterval
        var audioFileName: String
        var transcript: String?
        var summaryData: Data?
        var statusRaw: String
        var errorMessage: String?
        var notes: String = ""
        var segmentsData: Data?
        var speakerNamesData: Data?
        var isStarred: Bool = false

        init(createdAt: Date = .now) {
            let id = UUID()
            self.id = id
            self.title = Meeting.defaultTitle
            self.createdAt = createdAt
            self.duration = 0
            self.audioFileName = "\(id.uuidString).caf"
            self.statusRaw = MeetingStatus.recording.rawValue
        }

        var status: MeetingStatus {
            get { MeetingStatus(rawValue: statusRaw) ?? .failed }
            set { statusRaw = newValue.rawValue }
        }

        var summary: MeetingSummary? {
            get { summaryData.flatMap { try? JSONDecoder().decode(MeetingSummary.self, from: $0) } }
            set { summaryData = newValue.flatMap { try? JSONEncoder().encode($0) } }
        }

        var segments: [TranscriptSegment]? {
            get { segmentsData.flatMap { try? JSONDecoder().decode([TranscriptSegment].self, from: $0) } }
            set { segmentsData = newValue.flatMap { try? JSONEncoder().encode($0) } }
        }

        var audioURL: URL {
            URL.documentsDirectory.appending(path: audioFileName)
        }

        // MARK: Speakers

        private var speakerNames: [String: String] {
            get { speakerNamesData.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:] }
            set { speakerNamesData = try? JSONEncoder().encode(newValue) }
        }

        /// Speaker numbers in the order they first speak.
        var speakers: [Int] {
            var seen: [Int] = []
            for speaker in (segments ?? []).compactMap(\.speaker) where !seen.contains(speaker) {
                seen.append(speaker)
            }
            return seen
        }

        /// Labels are only worth showing when there's more than one voice.
        var hasSpeakers: Bool { speakers.count > 1 }

        func name(for speaker: Int) -> String {
            speakerNames[String(speaker)] ?? "Speaker \(speaker)"
        }

        func rename(speaker: Int, to name: String) {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            speakerNames[String(speaker)] = trimmed.isEmpty ? nil : trimmed
        }

        /// The summary is written with "Speaker 2" style labels; show the names the user gave instead.
        func resolvingSpeakerNames(in text: String) -> String {
            speakers.sorted(by: >).reduce(text) { text, speaker in
                text.replacingOccurrences(of: "Speaker \(speaker)", with: name(for: speaker))
            }
        }

        /// Case-insensitive match against the title, notes, summary and transcript.
        func matches(_ query: String) -> Bool {
            let summaryText = summary.map { ([$0.overview] + $0.keyPoints + $0.decisions + $0.actionItems).joined(separator: " ") }
            return [title, notes, summaryText ?? "", transcript ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }

        /// The transcript as sent to the summary model: one labelled line per turn when speakers are known.
        var transcriptForSummary: String {
            guard hasSpeakers, let segments else { return transcript ?? "" }
            return segments.map { segment in
                let label = segment.speaker.map { name(for: $0) } ?? "Unknown"
                return "\(label): \(segment.text)"
            }
            .joined(separator: "\n\n")
        }
    }
}

extension SchemaV1 {
    /// Version 1, frozen as it shipped. Only here so stores from that version can be migrated.
    @Model
    final class Meeting {
        var id: UUID
        var title: String
        var createdAt: Date
        var duration: TimeInterval
        var audioFileName: String
        var transcript: String?
        var summaryData: Data?
        var statusRaw: String
        var errorMessage: String?
        var notes: String = ""

        init(id: UUID, title: String, createdAt: Date, duration: TimeInterval, audioFileName: String, statusRaw: String) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.duration = duration
            self.audioFileName = audioFileName
            self.statusRaw = statusRaw
        }
    }
}
