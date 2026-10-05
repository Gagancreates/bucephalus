import ActivityKit
import Foundation
import Observation
import SwiftData

/// Owns the one recording in progress, whether it was started in the app or from the lock screen.
@MainActor
@Observable
final class RecordingController {
    static let shared = RecordingController()

    let recorder = AudioRecorder()
    let processor = MeetingProcessor()
    var container: ModelContainer?
    private(set) var meeting: Meeting?

    private var activity: Activity<RecordingAttributes>?

    /// Set when the user leaves the full-screen recorder to browse while recording continues.
    var isMinimized = false

    var isActive: Bool { meeting != nil }
    var isPaused: Bool { recorder.isPaused }

    private init() {}

    func start() async throws {
        guard meeting == nil else { return }
        isMinimized = false
        guard let context = container?.mainContext else { throw RecorderError.storageUnavailable }
        guard await recorder.requestPermission() else { throw RecorderError.noPermission }

        let meeting = Meeting()
        try recorder.start(to: meeting.audioURL)
        context.insert(meeting)
        try? context.save()
        self.meeting = meeting
        await startLiveActivity()
    }

    func togglePause() async {
        guard isActive else { return }
        if recorder.isPaused {
            recorder.resume()
        } else {
            recorder.pause()
        }
        await updateLiveActivity()
    }

    func stop() async {
        guard let meeting else { return }
        meeting.duration = recorder.stop()
        meeting.status = .transcribing
        try? meeting.modelContext?.save()
        self.meeting = nil
        processor.enqueue(meeting)
        await endLiveActivities()
    }

    /// Clears any activity left behind by a crash or force quit.
    func endLiveActivities() async {
        activity = nil
        for activity in Activity<RecordingAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func nextState() -> RecordingAttributes.ContentState {
        let now = Date.now
        return .init(
            startedAt: now.addingTimeInterval(-recorder.currentTime),
            pausedAt: recorder.isPaused ? now : nil
        )
    }

    private func startLiveActivity() async {
        await endLiveActivities()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        activity = try? Activity.request(
            attributes: RecordingAttributes(),
            content: .init(state: nextState(), staleDate: nil)
        )
    }

    private func updateLiveActivity() async {
        await activity?.update(.init(state: nextState(), staleDate: nil))
    }
}
