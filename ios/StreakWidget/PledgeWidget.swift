import WidgetKit
import SwiftUI

struct PledgeEntry: TimelineEntry {
    let date: Date
}

struct PledgeProvider: TimelineProvider {
    func placeholder(in context: Context) -> PledgeEntry {
        PledgeEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (PledgeEntry) -> ()) {
        completion(PledgeEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PledgeEntry>) -> ()) {
        let entry = PledgeEntry(date: Date())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct PledgeWidgetEntryView: View {
    var entry: PledgeProvider.Entry

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.11, green: 0.80, blue: 0.76), // teal light
                    Color(red: 0.09, green: 0.67, blue: 0.64)  // teal darker
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 6) {
                Text("✋")
                    .foregroundColor(.white)
                    .font(.system(size: 22))
                Text(NSLocalizedString("pledge_widget_label", comment: ""))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
        }
        .widgetURL(URL(string: "stoppr://pledge"))
    }
}

struct PledgeWidget: Widget {
    let kind: String = "PledgeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PledgeProvider()) { entry in
            PledgeWidgetEntryView(entry: entry)
                .containerBackground(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.11, green: 0.80, blue: 0.76),
                            Color(red: 0.09, green: 0.67, blue: 0.64)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    for: .widget
                )
        }
        .configurationDisplayName(NSLocalizedString("pledge_widget_display_name", comment: ""))
        .description(NSLocalizedString("pledge_widget_description_ios", comment: ""))
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    PledgeWidget()
} timeline: {
    PledgeEntry(date: Date())
}


