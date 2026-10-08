import Foundation
import SwiftData
import SwiftUI

/// A sample meeting for previewing the UI. Launch with the `-demo` argument to add and open it.
enum DemoData {
    private static let audioFileName = "demo.caf"

    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }
    /// `-record` starts a recording on launch, for previewing the Live Activity.
    static var startsRecording: Bool { ProcessInfo.processInfo.arguments.contains("-record") }
    /// `-minimized` starts a recording already tucked into the bottom bar, for screenshots.
    static var startsMinimized: Bool { ProcessInfo.processInfo.arguments.contains("-minimized") }
    /// `-drawer` and `-settings` open those on launch, for screenshots.
    /// `-cycleDrawer` opens and closes the drawer a few times, switching lists, for recording it.
    static var cyclesDrawer: Bool { ProcessInfo.processInfo.arguments.contains("-cycleDrawer") }
    static var opensDrawer: Bool { ProcessInfo.processInfo.arguments.contains("-drawer") }
    static var opensSettings: Bool { ProcessInfo.processInfo.arguments.contains("-settings") }
    /// `-activityPreview` shows the Live Activity designs on a lock-screen-like background.
    static var showsActivityPreview: Bool { ProcessInfo.processInfo.arguments.contains("-activityPreview") }
    /// `-demoTab transcript` (or `notes`) opens meetings on that tab.
    static var tab: String? { UserDefaults.standard.string(forKey: "demoTab") }

    @MainActor
    static func seedIfRequested(in context: ModelContext) -> Meeting? {
        guard isRequested else { return nil }
        let name = audioFileName
        let existing = try? context.fetch(FetchDescriptor<Meeting>(predicate: #Predicate { $0.audioFileName == name }))
        if let meeting = existing?.first {
            if meeting.notes.isEmpty { meeting.notes = notes }
            if meeting.segments == nil { addSpeakers(to: meeting) }
            return meeting
        }

        addCompanions(to: context)
        let meeting = Meeting(createdAt: .now.addingTimeInterval(-3 * 3600))
        meeting.audioFileName = audioFileName
        meeting.duration = 34 * 60
        meeting.transcript = transcript
        meeting.summary = summary
        meeting.title = summary.title
        meeting.notes = notes
        addSpeakers(to: meeting)
        meeting.status = .done
        context.insert(meeting)
        try? context.save()
        return meeting
    }

    private static let notes = """
    # Before signing
    - Ask Arjun whether the **deposit** is refundable
    - Check the exit clause with the lawyer

    ## Move
    1. Book movers for the last week of November
    2. Order the new signboard

    Morning light in the Indiranagar space is *really* good.
    """

    private static let summary = MeetingSummary(
        title: "Studio Lease and Launch Plan",
        overview: "Priya and Arjun walked through the two studio options and how the move affects the December launch. They settled on the Indiranagar space despite the higher rent, because it is ready to move into, and agreed to push the launch by one week to absorb the move.",
        keyPoints: [
            "Indiranagar is ₹1.4 lakh a month and move-in ready; Koramangala is ₹1.1 lakh but needs about six weeks of fit-out.",
            "The fit-out delay would cost more in lost bookings than the rent difference saves over a year.",
            "The current landlord wants 30 days' notice, so the overlap is at most two weeks of double rent.",
            "The booking site is on track, but payment testing has not started.",
            "Two of the five instructors have not confirmed their December availability.",
        ],
        decisions: [
            "Take the Indiranagar studio on a two-year lease.",
            "Move the public launch from 1 December to 8 December.",
            "Keep the opening-week offer at three classes for the price of one.",
        ],
        actionItems: [
            "Arjun to negotiate a rent-free first month and send the lease to the lawyer by Friday.",
            "Priya to give notice on the current space on Monday.",
            "Priya to chase the two instructors and confirm the December timetable.",
            "Arjun to start payment testing with the developer this week.",
        ]
    )

    /// A few more finished meetings so the list looks lived-in for screenshots.
    private static func addCompanions(to context: ModelContext) {
        let companions: [(String, Double, Double, Bool, String)] = [
            ("DBMS Lecture on Normalisation", -1.2, 52, true,
             "The lecture covered first to third normal form with a student-course example, and when denormalising is worth it."),
            ("Weekly 1:1 with Meera", -26, 28, false,
             "Meera and Gagan reviewed the sprint, agreed to cut the export feature from this release, and set goals for next week."),
            ("Client Call on Website Revamp", -50, 41, true,
             "The client approved the new homepage direction and asked for a pricing page by Friday."),
            ("Inventory Forecasting Class", -74, 47, false,
             "Simple exponential smoothing and Croston's method for intermittent demand, with a worked example on spare parts."),
        ]
        for (index, item) in companions.enumerated() {
            let meeting = Meeting(createdAt: .now.addingTimeInterval(item.1 * 3600))
            meeting.audioFileName = "demo-\(index).caf"
            meeting.title = item.0
            meeting.duration = item.2 * 60
            meeting.isStarred = item.3
            meeting.transcript = item.4
            meeting.segments = [TranscriptSegment(speaker: nil, start: 0, text: item.4)]
            meeting.summary = MeetingSummary(title: item.0, overview: item.4, keyPoints: [], decisions: [], actionItems: [])
            meeting.status = .done
            context.insert(meeting)
        }
    }

    private static func addSpeakers(to meeting: Meeting) {
        meeting.segments = conversation.map { TranscriptSegment(speaker: $0.0, start: $0.1, text: $0.2) }
        meeting.rename(speaker: 1, to: "Arjun")
        meeting.rename(speaker: 2, to: "Priya")
    }

    private static let conversation: [(Int, Double, String)] = [
        (1, 0, "Okay so I went to see both places yesterday and honestly the Indiranagar one is just ready, like you could run a class there tomorrow. The floor is done, the mirrors are up, there's a changing room, and the light in the morning is really good. The Koramangala one is bigger but it's a shell."),
        (2, 21, "Right, and what did they say on rent?"),
        (1, 24, "So Indiranagar is one point four a month and Koramangala is one point one."),
        (2, 30, "Okay so thirty thousand a month difference, that's three point six lakh a year."),
        (1, 37, "Yeah but the Koramangala guy said fit-out is going to take at least six weeks, and that's if the contractor shows up."),
        (2, 46, "Six weeks means we miss December completely."),
        (1, 49, "Exactly, and December is when everyone signs up. If we lose even half of the December bookings that's more than the rent difference for the whole year."),
        (2, 60, "Okay, that's a fair point. What about the lease term?"),
        (1, 64, "He wants two years with a five percent increase in the second year. I think we can ask for the first month free since we're signing for two years. I'll send it to the lawyer before we sign anything, I want her to look at the exit clause."),
        (2, 82, "When do we have to tell the current landlord?"),
        (1, 85, "Thirty days' notice."),
        (2, 88, "So if I tell him Monday, we overlap for maybe two weeks, which is fine. So then the launch. If we're moving in the last week of November I don't think the first of December is realistic."),
        (1, 101, "No, I'd rather push it a week and have it actually work. Let's say the eighth."),
        (2, 106, "Fine, the eighth. Is the booking site going to be ready?"),
        (1, 110, "The site itself is done, you can browse classes and pick a slot. Payments haven't been tested though, he's waiting on us for the gateway account. I'll get on a call with him this week and get that started."),
        (2, 124, "And instructors? Three have confirmed. Meera and Karthik haven't come back to me about December. I'll chase them, because I can't publish the timetable until I know."),
        (1, 137, "And the opening offer, are we still doing three classes for the price of one?"),
        (2, 141, "Yes, keep it, it's simple and people understand it. So Indiranagar, two years, launch on the eighth, and I'll talk to the landlord Monday."),
        (1, 150, "Perfect."),
    ]

    private static let transcript = """
    Okay so I went to see both places yesterday and honestly the Indiranagar one is just ready, like you could run a class there tomorrow. The floor is done, the mirrors are up, there's a changing room, and the light in the morning is really good. The Koramangala one is bigger but it's a shell. Right, and what did they say on rent? So Indiranagar is one point four a month and Koramangala is one point one. Okay so thirty thousand a month difference, that's three point six lakh a year. Yeah but the Koramangala guy said fit-out is going to take at least six weeks, and that's if the contractor shows up. Six weeks means we miss December completely. Exactly, and December is when everyone signs up. If we lose even half of the December bookings that's more than the rent difference for the whole year. Okay, that's a fair point. What about the lease term? He wants two years with a five percent increase in the second year. I think we can ask for the first month free since we're signing for two years. Yeah, let me try that. I'll send it to the lawyer before we sign anything, I want her to look at the exit clause. When do we have to tell the current landlord? Thirty days' notice. So if I tell him Monday, we overlap for maybe two weeks, which is fine. Okay. So then the launch. If we're moving in the last week of November I don't think the first of December is realistic. No, I'd rather push it a week and have it actually work. Let's say the eighth. Fine, the eighth. Is the booking site going to be ready? The site itself is done, you can browse classes and pick a slot. Payments haven't been tested though, he's waiting on us for the gateway account. I'll get on a call with him this week and get that started. And instructors? Three have confirmed. Meera and Karthik haven't come back to me about December. I'll chase them, because I can't publish the timetable until I know. And the opening offer, are we still doing three classes for the price of one? Yes, keep it, it's simple and people understand it. Okay. So Indiranagar, two years, launch on the eighth, and I'll talk to the landlord Monday. Perfect.
    """
}

/// Renders the Live Activity designs inside the app, since the simulator can't be locked from the command line.
struct ActivityPreview: View {
    private let recording = RecordingAttributes.ContentState(
        startedAt: .now.addingTimeInterval(-29), pausedAt: nil
    )
    private let paused = RecordingAttributes.ContentState(
        startedAt: .now.addingTimeInterval(-754), pausedAt: .now
    )

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.12, blue: 0.2), Color(red: 0.15, green: 0.35, blue: 0.55)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 28) {
                card(RecordingLockScreenView(state: recording))
                card(RecordingLockScreenView(state: paused))
                RecordingIslandExpandedView(state: recording)
                    .padding(.vertical, 18)
                    .padding(.horizontal, 12)
                    .background(.black, in: RoundedRectangle(cornerRadius: 40, style: .continuous))
            }
            .padding(.horizontal, 12)
            .environment(\.colorScheme, .dark)
        }
    }

    private func card(_ content: some View) -> some View {
        content
            .background(.ultraThinMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
