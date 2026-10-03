import Foundation
import SwiftData

/// A sample meeting for previewing the UI. Launch with the `-demo` argument to add and open it.
enum DemoData {
    private static let audioFileName = "demo.caf"

    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }
    /// `-demoTab transcript` (or `notes`) opens meetings on that tab.
    static var tab: String? { UserDefaults.standard.string(forKey: "demoTab") }

    @MainActor
    static func seedIfRequested(in context: ModelContext) -> Meeting? {
        guard isRequested else { return nil }
        let name = audioFileName
        let existing = try? context.fetch(FetchDescriptor<Meeting>(predicate: #Predicate { $0.audioFileName == name }))
        if let meeting = existing?.first {
            if meeting.notes.isEmpty { meeting.notes = notes }
            return meeting
        }

        let meeting = Meeting(createdAt: .now.addingTimeInterval(-3 * 3600))
        meeting.audioFileName = audioFileName
        meeting.duration = 34 * 60
        meeting.transcript = transcript
        meeting.summary = summary
        meeting.title = summary.title
        meeting.notes = notes
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

    private static let transcript = """
    Okay so I went to see both places yesterday and honestly the Indiranagar one is just ready, like you could run a class there tomorrow. The floor is done, the mirrors are up, there's a changing room, and the light in the morning is really good. The Koramangala one is bigger but it's a shell. Right, and what did they say on rent? So Indiranagar is one point four a month and Koramangala is one point one. Okay so thirty thousand a month difference, that's three point six lakh a year. Yeah but the Koramangala guy said fit-out is going to take at least six weeks, and that's if the contractor shows up. Six weeks means we miss December completely. Exactly, and December is when everyone signs up. If we lose even half of the December bookings that's more than the rent difference for the whole year. Okay, that's a fair point. What about the lease term? He wants two years with a five percent increase in the second year. I think we can ask for the first month free since we're signing for two years. Yeah, let me try that. I'll send it to the lawyer before we sign anything, I want her to look at the exit clause. When do we have to tell the current landlord? Thirty days' notice. So if I tell him Monday, we overlap for maybe two weeks, which is fine. Okay. So then the launch. If we're moving in the last week of November I don't think the first of December is realistic. No, I'd rather push it a week and have it actually work. Let's say the eighth. Fine, the eighth. Is the booking site going to be ready? The site itself is done, you can browse classes and pick a slot. Payments haven't been tested though, he's waiting on us for the gateway account. I'll get on a call with him this week and get that started. And instructors? Three have confirmed. Meera and Karthik haven't come back to me about December. I'll chase them, because I can't publish the timetable until I know. And the opening offer, are we still doing three classes for the price of one? Yes, keep it, it's simple and people understand it. Okay. So Indiranagar, two years, launch on the eighth, and I'll talk to the landlord Monday. Perfect.
    """
}
