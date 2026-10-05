import SwiftData
import SwiftUI

@main
struct BucephalusApp: App {
    @State private var processor = MeetingProcessor()
    private let container = Result { try Storage.openContainer() }

    var body: some Scene {
        WindowGroup {
            Group {
                switch container {
                case .success(let container):
                    HomeView()
                        .environment(processor)
                        .modelContainer(container)
                case .failure(let error):
                    StorageErrorView(message: error.localizedDescription)
                }
            }
            .tint(Theme.accent)
        }
    }
}

/// Shown instead of crashing when the saved meetings can't be opened. Nothing is deleted.
private struct StorageErrorView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Can't open your meetings", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Nothing has been deleted. Your recordings and a backup of your meetings are still on this iPhone. Installing a fixed version of the app will bring them back.\n\n\(message)")
        }
    }
}
