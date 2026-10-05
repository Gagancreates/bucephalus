import SwiftUI
import WidgetKit

@main
struct BucephalusWidgets: WidgetBundle {
    var body: some Widget {
        RecordingLiveActivity()
        RecordWidget()
        RecordControl()
    }
}
