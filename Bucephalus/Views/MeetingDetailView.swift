import SwiftUI

struct MeetingDetailView: View {
    @Environment(MeetingProcessor.self) private var processor
    @Bindable var meeting: Meeting

    private enum Tab: String, CaseIterable {
        case summary = "Summary"
        case transcript = "Transcript"
        case notes = "Notes"
    }

    @State private var tab: Tab = Tab(rawValue: (DemoData.tab ?? "").capitalized) ?? .summary
    @State private var renamingSpeaker: Int?
    @State private var speakerName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                Picker("View", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .summary: summaryContent
                case .transcript: transcriptContent
                case .notes: notesContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .task {
            guard DemoData.toursMeeting else { return }
            for next in [Tab.transcript, .notes] {
                try? await Task.sleep(for: .seconds(2.6))
                withAnimation(.snappy) { tab = next }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Rename speaker", isPresented: Binding(get: { renamingSpeaker != nil }, set: { if !$0 { renamingSpeaker = nil } })) {
            TextField("Name", text: $speakerName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let renamingSpeaker { meeting.rename(speaker: renamingSpeaker, to: speakerName) }
            }
        } message: {
            Text("Used everywhere this voice appears in this meeting, including the summary.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(meeting.isStarred ? "Unstar" : "Star", systemImage: meeting.isStarred ? "star.fill" : "star") {
                    meeting.isStarred.toggle()
                }
                .tint(meeting.isStarred ? .yellow : nil)
            }
            if let shareText {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: shareText)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(meeting.title)
                .font(.title2.weight(.semibold))
            Text("\(meeting.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(meeting.duration.shortDurationString)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var summaryContent: some View {
        if let summary = meeting.summary {
            VStack(alignment: .leading, spacing: 12) {
                Text(meeting.resolvingSpeakerNames(in: summary.overview))
                    .font(.callout)
                    .lineSpacing(4)
                    .card()
                SummarySection(title: "Key points", items: summary.keyPoints.map(meeting.resolvingSpeakerNames))
                SummarySection(title: "Decisions", icon: "checkmark", items: summary.decisions.map(meeting.resolvingSpeakerNames))
                SummarySection(title: "Action items", icon: "circle", items: summary.actionItems.map(meeting.resolvingSpeakerNames))
            }
            .textSelection(.enabled)
        } else {
            statusContent
        }
    }

    @ViewBuilder
    private var transcriptContent: some View {
        if let transcript = meeting.transcript {
            VStack(alignment: .leading, spacing: 18) {
                Text(transcriptCaption(for: transcript))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let segments = meeting.segments, !segments.isEmpty {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        TranscriptSegmentView(
                            segment: segment,
                            // Label a turn only where the speaker changes.
                            speakerLabel: speakerLabel(for: segment, after: index > 0 ? segments[index - 1] : nil),
                            onRename: { speaker in
                                let current = meeting.name(for: speaker)
                                speakerName = current == "Speaker \(speaker)" ? "" : current
                                renamingSpeaker = speaker
                            }
                        )
                    }
                } else {
                    Text(transcript)
                        .font(.callout)
                        .lineSpacing(6)
                        .foregroundStyle(.primary.opacity(0.85))
                        .textSelection(.enabled)
                }
            }
            .card()
        } else {
            statusContent
        }
    }

    private func transcriptCaption(for transcript: String) -> String {
        var parts = ["\(transcript.split(whereSeparator: \.isWhitespace).count) words"]
        if meeting.hasSpeakers {
            parts.append("\(meeting.speakers.count) speakers, tap a name to rename")
        } else {
            parts.append("transcribed on this iPhone")
        }
        return parts.joined(separator: " · ")
    }

    private func speakerLabel(for segment: TranscriptSegment, after previous: TranscriptSegment?) -> SpeakerLabel? {
        guard meeting.hasSpeakers, let speaker = segment.speaker, previous?.speaker != speaker else { return nil }
        let order = meeting.speakers.firstIndex(of: speaker) ?? 0
        return SpeakerLabel(speaker: speaker, name: meeting.name(for: speaker), color: Theme.speakerColor(order))
    }

    private var notesContent: some View {
        NotesView(text: $meeting.notes)
    }

    @ViewBuilder
    private var statusContent: some View {
        switch meeting.status {
        case .failed:
            VStack(alignment: .leading, spacing: 14) {
                Text(meeting.errorMessage ?? "Something went wrong.")
                    .foregroundStyle(.secondary)
                Button("Try again") { processor.enqueue(meeting) }
                    .buttonStyle(.bordered)
            }
        default:
            HStack(spacing: 12) {
                ProgressView()
                Text(progressText)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
    }

    private var progressText: String {
        if meeting.status == .transcribing, case .downloading(let fraction) = SpeechModelStatus.shared.state {
            return "Downloading the speech model (one time) · \(fraction.formatted(.percent.precision(.fractionLength(0))))"
        }
        return meeting.status == .transcribing ? "Transcribing on this iPhone…" : "\(meeting.status.progressLabel)…"
    }

    private var shareText: String? {
        guard let summary = meeting.summary else { return meeting.transcriptForSummary.nilIfEmpty }
        let named = meeting.resolvingSpeakerNames
        var lines = [meeting.title, "", named(summary.overview)]
        for (title, items) in [
            ("Key points", summary.keyPoints),
            ("Decisions", summary.decisions),
            ("Action items", summary.actionItems),
        ] where !items.isEmpty {
            lines += ["", title] + items.map { "• \(named($0))" }
        }
        if !meeting.notes.isEmpty {
            lines += ["", "Notes", meeting.notes]
        }
        return lines.joined(separator: "\n")
    }
}

private struct SpeakerLabel {
    let speaker: Int
    let name: String
    let color: Color
}

private struct TranscriptSegmentView: View {
    let segment: TranscriptSegment
    let speakerLabel: SpeakerLabel?
    let onRename: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let speakerLabel {
                HStack(spacing: 8) {
                    Button {
                        onRename(speakerLabel.speaker)
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(speakerLabel.color)
                                .frame(width: 7, height: 7)
                            Text(speakerLabel.name)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(speakerLabel.color)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Rename this speaker")

                    Text(segment.start.clockString)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 2)
            }
            Text(segment.text)
                .font(.callout)
                .lineSpacing(6)
                .foregroundStyle(.primary.opacity(0.85))
                .textSelection(.enabled)
        }
    }
}

private struct SummarySection: View {
    let title: String
    var icon: String?
    let items: [String]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        marker
                        Text(item)
                            .font(.callout)
                            .lineSpacing(3)
                    }
                }
            }
            .card()
        }
    }

    @ViewBuilder
    private var marker: some View {
        if let icon {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 16)
        } else {
            Circle()
                .fill(Theme.accent)
                .frame(width: 5, height: 5)
                .frame(width: 16)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 4 }
        }
    }
}

extension View {
    func card() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
