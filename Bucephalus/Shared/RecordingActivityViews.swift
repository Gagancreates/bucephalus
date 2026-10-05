import AppIntents
import SwiftUI

// Views for the recording Live Activity. They live in Shared so the app can render them for previews too.

/// The lock screen card.
struct RecordingLockScreenView: View {
    let state: RecordingAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                RecordingLabel(isPaused: state.isPaused)
                ElapsedTime(state: state)
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(state.isPaused ? 0.6 : 1))
            }

            Spacer(minLength: 0)

            PauseButton(isPaused: state.isPaused, size: 44)
            StopButton(size: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

/// The expanded Dynamic Island, minus the region wrappers.
struct RecordingIslandExpandedView: View {
    let state: RecordingAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                RecordingLabel(isPaused: state.isPaused)
                ElapsedTime(state: state)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(state.isPaused ? 0.6 : 1))
            }
            Spacer(minLength: 0)
            PauseButton(isPaused: state.isPaused, size: 40)
            StopButton(size: 40)
        }
        .padding(.horizontal, 8)
    }
}

struct RecordingLabel: View {
    let isPaused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isPaused ? Color.white.opacity(0.4) : Theme.recording)
                .frame(width: 6, height: 6)
            Text(isPaused ? "Paused" : "Recording")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}

/// Counts up on its own and freezes while paused; the system redraws it without app updates.
struct ElapsedTime: View {
    let state: RecordingAttributes.ContentState
    var alignment: TextAlignment = .leading

    var body: some View {
        Text(timerInterval: state.startedAt...Date.distantFuture, pauseTime: state.pausedAt, countsDown: false)
            .monospacedDigit()
            .multilineTextAlignment(alignment)
            // The timer reserves room for its widest value; pin it so it hugs its edge.
            .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
    }
}

struct PauseButton: View {
    let isPaused: Bool
    let size: CGFloat

    var body: some View {
        Button(intent: TogglePauseRecordingIntent()) {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size, height: size)
                .background(.white.opacity(0.16), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPaused ? "Resume recording" : "Pause recording")
    }
}

struct StopButton: View {
    let size: CGFloat

    var body: some View {
        Button(intent: StopRecordingIntent()) {
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .fill(Theme.accent)
                .frame(width: size * 0.3, height: size * 0.3)
                .frame(width: size, height: size)
                .background(.white, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop recording")
    }
}
