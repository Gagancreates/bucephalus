import ActivityKit
import SwiftUI
import WidgetKit

struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingAttributes.self) { context in
            RecordingLockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.4))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    RecordingIslandExpandedView(state: context.state)
                }
            } compactLeading: {
                RecordingDot(isPaused: context.state.isPaused)
                    .padding(.leading, 4)
            } compactTrailing: {
                ElapsedTime(state: context.state, alignment: .trailing)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 42)
            } minimal: {
                RecordingDot(isPaused: context.state.isPaused)
            }
            .keylineTint(Theme.accent)
        }
    }
}

private struct RecordingDot: View {
    let isPaused: Bool

    var body: some View {
        Image(systemName: isPaused ? "pause.fill" : "circle.fill")
            .font(.system(size: isPaused ? 11 : 9, weight: .bold))
            .foregroundStyle(isPaused ? Color.white.opacity(0.6) : Theme.recording)
    }
}
