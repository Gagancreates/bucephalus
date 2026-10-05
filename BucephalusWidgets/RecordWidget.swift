import AppIntents
import SwiftUI
import WidgetKit

/// A round lock screen widget: tap to start recording.
struct RecordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RecordWidget", provider: StaticProvider()) { _ in
            Button(intent: StartRecordingIntent()) {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "mic.fill")
                        .font(.system(size: 22, weight: .semibold))
                }
            }
            .buttonStyle(.plain)
            .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Record")
        .description("Start recording a conversation.")
        .supportedFamilies([.accessoryCircular])
    }
}

/// A Control Center and lock screen control (the buttons at the bottom of the lock screen).
struct RecordControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.gagancreates.bucephalus.record") {
            ControlWidgetButton(action: StartRecordingIntent()) {
                Label("Record", systemImage: "waveform")
            }
        }
        .displayName("Record")
        .description("Start recording a conversation in Bucephalus.")
    }
}

private struct StaticProvider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry() }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry()], policy: .never))
    }

    struct Entry: TimelineEntry {
        let date = Date.now
    }
}
