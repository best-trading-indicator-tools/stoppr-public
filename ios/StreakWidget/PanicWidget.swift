import WidgetKit
import SwiftUI

struct PanicEntry: TimelineEntry {
    let date: Date
}

struct PanicProvider: TimelineProvider {
    func placeholder(in context: Context) -> PanicEntry { PanicEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (PanicEntry) -> ()) {
        completion(PanicEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PanicEntry>) -> ()) {
        let entry = PanicEntry(date: Date())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct PanicWidgetEntryView: View {
    var entry: PanicProvider.Entry

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.929, green: 0.196, blue: 0.447),
                    Color(red: 0.992, green: 0.365, blue: 0.196)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 22))
                Text(NSLocalizedString("panic_button_label", comment: ""))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
                    .lineLimit(2)
            }
        }
        .widgetURL(URL(string: "stoppr://panic"))
    }
}

struct PanicWidget: Widget {
    let kind: String = "PanicWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PanicProvider()) { entry in
            PanicWidgetEntryView(entry: entry)
                .containerBackground(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.929, green: 0.196, blue: 0.447),
                            Color(red: 0.992, green: 0.365, blue: 0.196)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    for: .widget
                )
        }
        .configurationDisplayName(NSLocalizedString("panic_widget_display_name", comment: ""))
        .description(NSLocalizedString("panic_widget_description_ios", comment: ""))
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    PanicWidget()
} timeline: {
    PanicEntry(date: Date())
}


