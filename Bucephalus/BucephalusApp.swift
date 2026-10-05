import SwiftData
import SwiftUI

@main
struct BucephalusApp: App {
    private let container = Result { try Storage.openContainer() }
    private let recording = RecordingController.shared

    init() {
        if case .success(let container) = container {
            recording.container = container
        }
        // The lock screen widget, Control Center button and Live Activity reach the recorder through these.
        RecordingIntentHandler.start = { try await RecordingController.shared.start() }
        RecordingIntentHandler.stop = { await RecordingController.shared.stop() }
        RecordingIntentHandler.togglePause = { await RecordingController.shared.togglePause() }
        RecordingIntentHandler.toggle = {
            let recording = RecordingController.shared
            if recording.isActive { await recording.stop() } else { try await recording.start() }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch container {
                case .success where DemoData.showsActivityPreview:
                    ActivityPreview()
                case .success(let container):
                    RootView()
                        .environment(recording)
                        .environment(recording.processor)
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
