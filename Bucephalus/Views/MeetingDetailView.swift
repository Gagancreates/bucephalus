import SwiftUI

struct MeetingDetailView: View {
    @Environment(MeetingProcessor.self) private var processor
    let meeting: Meeting

    private enum Tab: String, CaseIterable {
        case summary = "Summary"
        case transcript = "Transcript"
    }

    @State private var tab: Tab = .summary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                Picker("View", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .summary: summaryContent
                case .transcript: transcriptContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
        VStack(alignment: .leading, spacing: 6) {
            Text(meeting.title)
                .font(.largeTitle.bold())
            Text("\(meeting.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(meeting.duration.shortDurationString)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var summaryContent: some View {
        if let summary = meeting.summary {
            VStack(alignment: .leading, spacing: 28) {
                Text(summary.overview)
                    .font(.body)
                    .lineSpacing(4)
                SummarySection(title: "Key points", items: summary.keyPoints)
                SummarySection(title: "Decisions", items: summary.decisions)
                SummarySection(title: "Action items", items: summary.actionItems)
            }
            .textSelection(.enabled)
        } else {
            statusContent
        }
    }

    @ViewBuilder
    private var transcriptContent: some View {
        if let transcript = meeting.transcript {
            Text(transcript)
                .font(.body)
                .lineSpacing(5)
                .textSelection(.enabled)
        } else {
            statusContent
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        switch meeting.status {
        case .failed:
            VStack(alignment: .leading, spacing: 14) {
                Text(meeting.errorMessage ?? "Something went wrong.")
                    .foregroundStyle(.secondary)
                Button("Try again") { processor.enqueue(meeting) }
                    .buttonStyle(.borderedProminent)
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
        return lines.joined(separator: "\n")
    }
}

private struct SummarySection: View {
    let title: String
    let items: [String]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 5, height: 5)
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 4 }
                        Text(item)
                            .lineSpacing(3)
                    }
                }
            }
        }
    }
}
