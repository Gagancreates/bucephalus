import SwiftUI

struct RecordingView: View {
    @Environment(RecordingController.self) private var recording

    private var recorder: AudioRecorder { recording.recorder }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Theme.recording)
                        .frame(width: 8, height: 8)
                        .opacity(recorder.isRecording && !recorder.isPaused ? 1 : 0.3)
                    Text(recorder.isPaused ? "Paused" : recorder.isRecording ? "Recording" : "Starting")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                // Leave the recorder to browse meetings; recording carries on.
                Button {
                    recording.isMinimized = true
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .accessibilityLabel("Back to meetings")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
            }
            .padding(.top, 12)

            Spacer()

            Text(recorder.elapsed.clockString)
                .font(.system(size: 64, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.default, value: Int(recorder.elapsed))

            WaveformView(levels: recorder.levels)
                .frame(height: 96)
                .padding(.horizontal, 32)
                .padding(.top, 40)

            Spacer()

            Text("You can lock your phone. Recording continues.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 28)

            HStack(spacing: 28) {
                Button {
                    Task { await recording.togglePause() }
                } label: {
                    Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 60, height: 60)
                        .background(Color(.secondarySystemBackground), in: .circle)
                }
                .accessibilityLabel(recorder.isPaused ? "Resume recording" : "Pause recording")
                .sensoryFeedback(.impact(weight: .light), trigger: recorder.isPaused)

                Button {
                    Task { await recording.stop() }
                } label: {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.onAccent)
                        .frame(width: 26, height: 26)
                        .frame(width: 80, height: 80)
                        .background(Theme.accent, in: .circle)
                }
                .accessibilityLabel("Stop recording")
                .sensoryFeedback(.success, trigger: recorder.isRecording) { old, new in old && !new }

                // Balances the pause button so stop stays centred.
                Color.clear.frame(width: 60, height: 60)
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
}

struct WaveformView: View {
    let levels: [CGFloat]

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .center, spacing: 3) {
                ForEach(levels.indices, id: \.self) { index in
                    Capsule()
                        .fill(Theme.accent.opacity(0.2 + 0.8 * Double(index) / Double(levels.count)))
                        .frame(height: max(4, levels[index] * proxy.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.linear(duration: 0.06), value: levels)
        }
    }
}

/// Shown at the bottom of the meetings screens while a recording runs in the background.
struct RecordingBar: View {
    @Environment(RecordingController.self) private var recording

    private var recorder: AudioRecorder { recording.recorder }

    var body: some View {
        HStack(spacing: 12) {
            // Tapping the left side reopens the full recorder.
            Button {
                recording.isMinimized = false
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(recorder.isPaused ? Color.secondary : Theme.recording)
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(recorder.isPaused ? "Paused" : "Recording")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(recorder.elapsed.clockString)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.primary)
                            .contentTransition(.numericText())
                            .animation(.default, value: Int(recorder.elapsed))
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open recorder")

            Button {
                Task { await recording.togglePause() }
            } label: {
                Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 40, height: 40)
                    .background(Color(.tertiarySystemFill), in: .circle)
            }
            .accessibilityLabel(recorder.isPaused ? "Resume recording" : "Pause recording")

            Button {
                Task { await recording.stop() }
            } label: {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.onAccent)
                    .frame(width: 13, height: 13)
                    .frame(width: 40, height: 40)
                    .background(Theme.accent, in: .circle)
            }
            .accessibilityLabel("Stop recording")
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
    }
}
