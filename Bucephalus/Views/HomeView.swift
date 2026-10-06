import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MeetingProcessor.self) private var processor
    @Environment(RecordingController.self) private var recording
    @Query(sort: \Meeting.createdAt, order: .reverse) private var allMeetings: [Meeting]

    let filter: MeetingFilter
    @Binding var path: [Meeting]
    @Binding var isSearching: Bool
    let openDrawer: () -> Void

    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @State private var recordingError: String?
    @State private var renameTarget: Meeting?
    @State private var renameText = ""
    @State private var showingRename = false
    @State private var deleteTarget: Meeting?
    @State private var showingDelete = false

    private var meetings: [Meeting] {
        let filtered = filter == .starred ? allMeetings.filter(\.isStarred) : allMeetings
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return filtered }
        return filtered.filter { $0.matches(query) }
    }

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
            .navigationTitle(filter.title)
            .navigationDestination(for: Meeting.self) { MeetingDetailView(meeting: $0) }
            // Our own header instead of the system bar: the system bar re-lays out its large title and
            // search field while the drawer slides the screen, so they drifted left and snapped back.
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: isSearching) { _, searching in searchFocused = searching }
            .onChange(of: searchFocused) { _, focused in if focused { isSearching = true } }
            .safeAreaInset(edge: .bottom) {
                if !recording.isActive { recordButton }
            }
        }
        // While recording in the background, a bar on every screen leads back to the recorder.
        .safeAreaInset(edge: .bottom) {
            if recording.isActive && recording.isMinimized {
                RecordingBar()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: recording.isMinimized)
        // Driven by the controller, so a recording started from the lock screen shows up here too.
        .fullScreenCover(isPresented: Binding(
            get: { recording.isActive && !recording.isMinimized },
            set: { if !$0 { recording.isMinimized = true } }
        )) {
            RecordingView()
        }
        .alert("Can't record", isPresented: Binding(get: { recordingError != nil }, set: { if !$0 { recordingError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(recordingError ?? "")
        }
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
            if !recording.isActive { await recording.endLiveActivities() }
            if DemoData.startsRecording || DemoData.startsMinimized {
                try? await recording.start()
                if DemoData.startsMinimized { recording.isMinimized = true }
            }
            if let demo = DemoData.seedIfRequested(in: modelContext) { path = [demo] }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: openDrawer) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .accessibilityLabel("Menu")

            Text(filter.title)
                .font(.largeTitle.bold())
                .padding(.top, 6)

            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Titles, transcripts, notes", text: $searchText)
                        .focused($searchFocused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button("Clear", systemImage: "xmark.circle.fill") { searchText = "" }
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Color(.tertiarySystemFill), in: .capsule)

                if searchFocused {
                    Button("Cancel") {
                        searchText = ""
                        searchFocused = false
                        isSearching = false
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.25), value: searchFocused)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
    }

    private var list: some View {
        List {
            ForEach(days, id: \.day) { group in
                Section {
                    ForEach(group.meetings) { meeting in
                        NavigationLink(value: meeting) { MeetingRow(meeting: meeting) }
                            .swipeActions(edge: .leading) {
                                Button(meeting.isStarred ? "Unstar" : "Star",
                                       systemImage: meeting.isStarred ? "star.slash" : "star") {
                                    meeting.isStarred.toggle()
                                }
                                .tint(.yellow)
                            }
                            .contextMenu {
                                Button(meeting.isStarred ? "Unstar" : "Star",
                                       systemImage: meeting.isStarred ? "star.slash" : "star") {
                                    meeting.isStarred.toggle()
                                }
                                if FileManager.default.fileExists(atPath: meeting.audioURL.path), !meeting.status.isInProgress {
                                    Button("Transcribe again", systemImage: "arrow.clockwise") {
                                        meeting.transcript = nil
                                        meeting.segments = nil
                                        meeting.summary = nil
                                        processor.enqueue(meeting)
                                    }
                                }
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

    @ViewBuilder
    private var emptyState: some View {
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if filter == .starred {
            ContentUnavailableView(
                "No starred meetings",
                systemImage: "star",
                description: Text("Swipe right on a meeting, or long-press it, to star it.")
            )
        } else {
            ContentUnavailableView(
                "No meetings yet",
                systemImage: "waveform",
                description: Text("Tap the button below, put your phone on the table, and talk.")
            )
        }
    }

    private var recordButton: some View {
        Button(action: startRecording) {
            Image(systemName: "mic.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 72, height: 72)
                .background(Theme.accent, in: .circle)
                .shadow(color: Theme.accent.opacity(0.4), radius: 18, y: 8)
        }
        .accessibilityLabel("Start recording")
        .sensoryFeedback(.impact(weight: .medium), trigger: recording.isActive)
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

    private func startRecording() {
        Task {
            do {
                try await recording.start()
            } catch {
                recordingError = error.localizedDescription
            }
        }
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
        for meeting in allMeetings where meeting.status.isInProgress
            && meeting.id != recording.meeting?.id {
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
            HStack(spacing: 6) {
                Text(meeting.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if meeting.isStarred {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }
            HStack(spacing: 6) {
                Text(meeting.createdAt.formatted(date: .omitted, time: .shortened))
                if meeting.duration > 0 {
                    Text("·")
                    Text(meeting.duration.shortDurationString)
                }
                switch meeting.status {
                case .transcribing, .diarizing, .summarizing, .recording:
                    Text("·")
                    Text(meeting.status.progressLabel)
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
