import SwiftData
import SwiftUI

@main
struct BusyFailersApp: App {
    @State private var processor = MeetingProcessor()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(processor)
                .tint(Theme.accent)
        }
        .modelContainer(for: Meeting.self)
    }
}
