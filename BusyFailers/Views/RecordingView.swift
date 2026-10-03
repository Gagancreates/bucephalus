import SwiftData
import SwiftUI

struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(MeetingProcessor.self) private var processor

    @State private var recorder = AudioRecorder()
    @State private var meeting: Meeting?
    @State private var problem: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 8, height: 8)
                    .opacity(recorder.isRecording ? 1 : 0.3)
                Text(recorder.isRecording ? "Recording" : "Starting")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)

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

            Button(action: stop) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white)
                    .frame(width: 26, height: 26)
                    .frame(width: 80, height: 80)
                    .background(Theme.accent, in: .circle)
            }
            .accessibilityLabel("Stop recording")
            .sensoryFeedback(.success, trigger: recorder.isRecording) { old, new in old && !new }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .task { await start() }
        .alert("Can't record", isPresented: .constant(problem != nil)) {
            Button("OK") { dismiss() }
        } message: {
            Text(problem ?? "")
        }
    }

    private func start() async {
        guard meeting == nil else { return }
        guard await recorder.requestPermission() else {
            problem = "Allow microphone access for Busy Failers in Settings."
            return
        }
        let meeting = Meeting()
        do {
            try recorder.start(to: meeting.audioURL)
            modelContext.insert(meeting)
            try? modelContext.save()
            self.meeting = meeting
        } catch {
            problem = error.localizedDescription
        }
    }

    private func stop() {
        guard let meeting else {
            dismiss()
            return
        }
        meeting.duration = recorder.stop()
        meeting.status = .transcribing
        try? modelContext.save()
        processor.enqueue(meeting)
        dismiss()
    }
}

struct WaveformView: View {
    let levels: [CGFloat]

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .center, spacing: 3) {
                ForEach(levels.indices, id: \.self) { index in
                    Capsule()
                        .fill(Theme.accent.opacity(0.35 + 0.65 * Double(index) / Double(levels.count)))
                        .frame(height: max(4, levels[index] * proxy.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.linear(duration: 0.06), value: levels)
        }
    }
}
