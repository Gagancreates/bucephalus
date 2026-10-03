import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MeetingProcessor.self) private var processor
    @Query(sort: \Meeting.createdAt, order: .reverse) private var meetings: [Meeting]

    @State private var isRecording = false
    @State private var showingSettings = false
    @State private var path: [Meeting] = []
    @State private var renameTarget: Meeting?
    @State private var renameText = ""
    @State private var showingRename = false
    @State private var deleteTarget: Meeting?
    @State private var showingDelete = false

    private var days: [(day: Date, meetings: [Meeting])] {
        Dictionary(grouping: meetings) { Calendar.current.startOfDay(for: $0.createdAt) }
            .map { (day: $0.key, meetings: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack(path: $path) {
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
        .alert("Rename meeting", isPresented: $showingRename) {
            TextField("Meeting name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { renameTarget?.title = name }
            }
        }
        .alert("Delete this meeting?", isPresented: $showingDelete) {
            Button("Delete", role: .destructive) {
                if let deleteTarget { delete(deleteTarget) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The recording, transcript, summary and notes will be removed.")
        }
        .task {
            resumeUnfinished()
            if let demo = DemoData.seedIfRequested(in: modelContext) { path = [demo] }
        }
    }

    private var list: some View {
        List {
            ForEach(days, id: \.day) { group in
                Section {
                    ForEach(group.meetings) { meeting in
                        NavigationLink(value: meeting) { MeetingRow(meeting: meeting) }
                            .contextMenu {
                                Button("Rename", systemImage: "pencil") {
                                    renameTarget = meeting
                                    renameText = meeting.title
                                    showingRename = true
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    deleteTarget = meeting
                                    showingDelete = true
                                }
                            }
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
                .foregroundStyle(Theme.onAccent)
                .frame(width: 72, height: 72)
                .background(Theme.accent, in: .circle)
                .shadow(color: Theme.accent.opacity(0.4), radius: 18, y: 8)
        }
        .accessibilityLabel("Start recording")
        .sensoryFeedback(.impact(weight: .medium), trigger: isRecording)
        .padding(.top, 28)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        // Fades the list out behind the button instead of letting rows collide with it.
        .background(
            LinearGradient(
                stops: [.init(color: .clear, location: 0), .init(color: Color(.systemBackground), location: 0.45)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
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
                        .foregroundStyle(.primary)
                case .failed:
                    Text("·")
                    Text("Needs attention").foregroundStyle(.primary)
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
