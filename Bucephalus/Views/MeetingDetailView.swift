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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
                Text(summary.overview)
                    .font(.callout)
                    .lineSpacing(4)
                    .card()
                SummarySection(title: "Key points", items: summary.keyPoints)
                SummarySection(title: "Decisions", icon: "checkmark", items: summary.decisions)
                SummarySection(title: "Action items", icon: "circle", items: summary.actionItems)
            }
            .textSelection(.enabled)
        } else {
            statusContent
        }
    }

    @ViewBuilder
    private var transcriptContent: some View {
        if let transcript = meeting.transcript {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(transcript.split(whereSeparator: \.isWhitespace).count) words · transcribed on this iPhone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(transcript)
                    .font(.callout)
                    .lineSpacing(6)
                    .foregroundStyle(.primary.opacity(0.85))
                    .textSelection(.enabled)
            }
            .card()
        } else {
            statusContent
        }
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
                Text(meeting.status == .summarizing ? "Summarising…" : "Transcribing on this iPhone…")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
    }

    private var shareText: String? {
        guard let summary = meeting.summary else { return meeting.transcript }
        var lines = [meeting.title, "", summary.overview]
        for (title, items) in [
            ("Key points", summary.keyPoints),
            ("Decisions", summary.decisions),
            ("Action items", summary.actionItems),
        ] where !items.isEmpty {
            lines += ["", title] + items.map { "• \($0)" }
        }
        if !meeting.notes.isEmpty {
            lines += ["", "Notes", meeting.notes]
        }
        return lines.joined(separator: "\n")
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
