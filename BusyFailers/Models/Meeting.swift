import Foundation
import SwiftData

enum MeetingStatus: String {
    case recording, transcribing, summarizing, done, failed
}

struct MeetingSummary: Codable {
    var title: String
    var overview: String
    var keyPoints: [String]
    var decisions: [String]
    var actionItems: [String]
}

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

    init(createdAt: Date = .now) {
        let id = UUID()
        self.id = id
        self.title = "New meeting"
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

    var audioURL: URL {
        URL.documentsDirectory.appending(path: audioFileName)
    }
}
