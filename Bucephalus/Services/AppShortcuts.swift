import AppIntents

/// Shows Bucephalus in the Shortcuts app, Siri, Spotlight and the Action Button settings.
struct BucephalusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleRecordingIntent(),
            phrases: [
                "Record with \(.applicationName)",
                "Start \(.applicationName)",
                "Stop \(.applicationName)",
            ],
            shortTitle: "Record or Stop",
            systemImageName: "waveform"
        )
    }
}
