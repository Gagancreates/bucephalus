import AVFoundation
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AudioRecorder {
    static let levelCount = 44

    private(set) var isRecording = false
    private(set) var isPaused = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var levels: [CGFloat] = Array(repeating: 0, count: AudioRecorder.levelCount)

    private var recorder: AVAudioRecorder?
    // Our own clock: AVAudioRecorder.currentTime isn't reliable while paused, so time is counted here.
    private var accumulated: TimeInterval = 0
    private var segmentStart: Date?
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
            AVEncoderBitRateKey: AudioQuality.current.bitRate,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.record() else { throw RecorderError.couldNotStart }
        self.recorder = recorder
        accumulated = 0
        segmentStart = .now
        elapsed = 0
        isRecording = true
        isPaused = false

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
        let duration = currentTime
        accumulated = 0
        segmentStart = nil
        recorder?.stop()
        recorder = nil
        timer?.invalidate()
        timer = nil
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = nil
        isRecording = false
        isPaused = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return duration
    }

    func pause() {
        guard let recorder, !isPaused else { return }
        recorder.pause()
        holdClock()
        isPaused = true
    }

    func resume() {
        guard let recorder, isPaused else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        recorder.record()
        runClock()
        isPaused = false
    }

    /// Seconds recorded so far, excluding pauses.
    var currentTime: TimeInterval {
        accumulated + (segmentStart.map { Date.now.timeIntervalSince($0) } ?? 0)
    }

    private func holdClock() {
        accumulated = currentTime
        segmentStart = nil
        elapsed = accumulated
    }

    private func runClock() {
        if segmentStart == nil { segmentStart = .now }
    }

    private func tick() {
        guard let recorder else { return }
        guard recorder.isRecording else {
            // Paused or interrupted: let the waveform settle to flat.
            levels.removeFirst()
            levels.append(0)
            return
        }
        elapsed = currentTime
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)
        var normalized = CGFloat(max(0, min(1, (db + 50) / 50)))
        if DemoData.fakesLevels {
            // Syllable-like bursts with pauses, for the demo video.
            let t = elapsed
            let envelope = max(0, sin(t * 2.3) * 0.6 + sin(t * 5.1) * 0.3 + 0.25)
            normalized = CGFloat(min(1, envelope * Double.random(in: 0.6...1.1)))
        }
        levels.removeFirst()
        levels.append(normalized)
    }

    // A phone call pauses the recorder: stop the clock, and pick up again once it ends unless the user paused.
    private func handleInterruption(typeRaw: UInt?) {
        guard let typeRaw, let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
        switch type {
        case .began:
            holdClock()
        case .ended where !isPaused:
            try? AVAudioSession.sharedInstance().setActive(true)
            recorder?.record()
            runClock()
        default:
            break
        }
    }
}

enum RecorderError: LocalizedError {
    case couldNotStart, noPermission, storageUnavailable

    var errorDescription: String? {
        switch self {
        case .couldNotStart: "Recording couldn't start. Check that another app isn't using the microphone."
        case .noPermission: "Allow microphone access for Bucephalus in Settings."
        case .storageUnavailable: "Your meetings couldn't be opened, so nothing can be saved right now."
        }
    }
}
