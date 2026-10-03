import AVFoundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AudioRecorder {
    static let levelCount = 44

    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var levels: [CGFloat] = Array(repeating: 0, count: AudioRecorder.levelCount)

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var interruptionObserver: NSObjectProtocol?

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start(to url: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)

        // CAF stays readable if the app dies mid-recording; M4A does not.
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.record() else { throw RecorderError.couldNotStart }
        self.recorder = recorder
        isRecording = true

        timer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: session, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor in self?.handleInterruption(typeRaw: raw) }
        }
    }

    /// Stops recording and returns the recorded duration.
    @discardableResult
    func stop() -> TimeInterval {
        let duration = recorder?.currentTime ?? elapsed
        recorder?.stop()
        recorder = nil
        timer?.invalidate()
        timer = nil
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return duration
    }

    private func tick() {
        guard let recorder, recorder.isRecording else { return }
        elapsed = recorder.currentTime
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)
        let normalized = CGFloat(max(0, min(1, (db + 50) / 50)))
        levels.removeFirst()
        levels.append(normalized)
    }

    // A phone call pauses the recorder; pick up again once it ends.
    private func handleInterruption(typeRaw: UInt?) {
        guard let typeRaw, AVAudioSession.InterruptionType(rawValue: typeRaw) == .ended else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        recorder?.record()
    }
}

enum RecorderError: LocalizedError {
    case couldNotStart

    var errorDescription: String? {
        "Recording couldn't start. Check that another app isn't using the microphone."
    }
}
