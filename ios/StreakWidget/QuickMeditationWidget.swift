import WidgetKit
import SwiftUI

struct QuickMeditationEntry: TimelineEntry {
    let date: Date
}

struct QuickMeditationProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickMeditationEntry { QuickMeditationEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (QuickMeditationEntry) -> ()) { completion(QuickMeditationEntry(date: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickMeditationEntry>) -> ()) {
        completion(Timeline(entries: [QuickMeditationEntry(date: Date())], policy: .after(Date().addingTimeInterval(900))))
    }
}

struct QuickMeditationWidgetEntryView: View {
    var entry: QuickMeditationProvider.Entry
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.98, green: 0.78, blue: 0.19), // gold
                    Color(red: 0.95, green: 0.68, blue: 0.10)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.white)
                    .font(.system(size: 22))
                Text(NSLocalizedString("quick_meditation_label", comment: ""))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
                    .lineLimit(2)
            }
        }
        .widgetURL(URL(string: "stoppr://meditation"))
    }
}

struct QuickMeditationWidget: Widget {
    let kind: String = "QuickMeditationWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickMeditationProvider()) { entry in
            QuickMeditationWidgetEntryView(entry: entry)
                .containerBackground(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.98, green: 0.78, blue: 0.19),
                            Color(red: 0.95, green: 0.68, blue: 0.10)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    for: .widget
                )
        }
        .configurationDisplayName(NSLocalizedString("quick_meditation_display_name", comment: ""))
        .description(NSLocalizedString("quick_meditation_description_ios", comment: ""))
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    QuickMeditationWidget()
} timeline: {
    QuickMeditationEntry(date: Date())
}


