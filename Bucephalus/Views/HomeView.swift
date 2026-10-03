import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MeetingProcessor.self) private var processor
    @Query(sort: \Meeting.createdAt, order: .reverse) private var meetings: [Meeting]

    @State private var isRecording = false
    @State private var showingSettings = false

    private var days: [(day: Date, meetings: [Meeting])] {
        Dictionary(grouping: meetings) { Calendar.current.startOfDay(for: $0.createdAt) }
            .map { (day: $0.key, meetings: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            Group {
                if meetings.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Meetings")
            .navigationDestination(for: Meeting.self) { MeetingDetailView(meeting: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                }
            }
            .safeAreaInset(edge: .bottom) { recordButton }
        }
        .fullScreenCover(isPresented: $isRecording) { RecordingView() }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .task { resumeUnfinished() }
    }

    private var list: some View {
        List {
            ForEach(days, id: \.day) { group in
                Section {
                    ForEach(group.meetings) { meeting in
                        NavigationLink(value: meeting) { MeetingRow(meeting: meeting) }
                    }
                    .onDelete { offsets in
                        offsets.map { group.meetings[$0] }.forEach(delete)
                    }
                } header: {
                    Text(dayTitle(group.day))
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No meetings yet",
            systemImage: "waveform",
            description: Text("Tap the button below, put your phone on the table, and talk.")
        )
    }

    private var recordButton: some View {
        Button {
            isRecording = true
        } label: {
            Image(systemName: "mic.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Theme.accent, in: .circle)
                .shadow(color: Theme.accent.opacity(0.35), radius: 16, y: 8)
        }
        .accessibilityLabel("Start recording")
        .sensoryFeedback(.impact(weight: .medium), trigger: isRecording)
        .padding(.bottom, 8)
    }

    private func dayTitle(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private func delete(_ meeting: Meeting) {
        try? FileManager.default.removeItem(at: meeting.audioURL)
        modelContext.delete(meeting)
    }

    // Picks up anything left mid-flight by a crash or a force quit.
    private func resumeUnfinished() {
        for meeting in meetings where [.recording, .transcribing, .summarizing].contains(meeting.status) {
            if FileManager.default.fileExists(atPath: meeting.audioURL.path) {
                processor.enqueue(meeting)
            } else {
                modelContext.delete(meeting)
            }
        }
    }
}

private struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(meeting.title)
                .font(.body.weight(.medium))
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(meeting.createdAt.formatted(date: .omitted, time: .shortened))
                if meeting.duration > 0 {
                    Text("·")
                    Text(meeting.duration.shortDurationString)
                }
                switch meeting.status {
                case .transcribing, .summarizing, .recording:
                    Text("·")
                    Text(meeting.status == .summarizing ? "Summarising" : "Transcribing")
                        .foregroundStyle(Theme.accent)
                case .failed:
                    Text("·")
                    Text("Needs attention").foregroundStyle(Theme.accent)
                case .done:
                    EmptyView()
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
