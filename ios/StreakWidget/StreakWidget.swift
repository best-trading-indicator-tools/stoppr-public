//
//  StreakWidget.swift
//  StreakWidget
//
//  Created by David Attias on 03/05/2025.
//

import WidgetKit
import SwiftUI

// Define App Group and UserDefaults key constants
let appGroupIdentifier = "group.YOUR_BUNDLE_ID.shared" // TODO: Replace with your app group identifier
let streakStartTimestampKey = "streak_start_timestamp" // Matches key used in Flutter StreakService
let localizedLabelKey = "widget_localized_label_sugar_free_since" // New key for the localized label
let subscriptionStatusKey = "widget_has_active_subscription" // New key for subscription status
let subscribePromptKey = "widget_subscribeToTrackStreak" // Key for the localized subscribe prompt

// --- Timeline Provider ---
struct Provider: TimelineProvider {
    // Provides a placeholder view for the widget gallery
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(
            date: Date(),
            startTime: nil,
            localizedLabel: NSLocalizedString("widget_sugarFreeSince", comment: ""),
            hasActiveSubscription: false,
            subscribePrompt: NSLocalizedString("widget_subscribeToTrackStreak", comment: "")
        )
    }

    // Provides a snapshot view for transient situations
    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> ()) {
        let data = getStreakData()
        let entry = StreakEntry(date: Date(), startTime: data.startTime, localizedLabel: data.localizedLabel, hasActiveSubscription: data.hasActiveSubscription, subscribePrompt: data.subscribePrompt)
        completion(entry)
    }

    // Provides the timeline (sequence of views) for the widget
    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> ()) {
        let currentDate = Date()
        let data = getStreakData()
        
        // Create a timeline entry for the current time
        let entry = StreakEntry(date: currentDate, startTime: data.startTime, localizedLabel: data.localizedLabel, hasActiveSubscription: data.hasActiveSubscription, subscribePrompt: data.subscribePrompt)

        // Calculate the next update time (e.g., 5 minutes from now)
        // iOS will still manage the actual update frequency based on budget.
        // Rely on the Flutter app sending `HomeWidget.updateWidget` for more timely updates.
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)!

        // Create the timeline with the single entry and a less frequent refresh policy
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        completion(timeline)
    }

    // Helper to read data from shared UserDefaults
    private func getStreakData() -> (startTime: Date?, localizedLabel: String, hasActiveSubscription: Bool, subscribePrompt: String) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("Error: Could not access App Group UserDefaults")
            return (
                nil,
                NSLocalizedString("widget_sugarFreeSince", comment: ""),
                false,
                NSLocalizedString("widget_subscribeToTrackStreak", comment: "")
            )
        }
        
        let timestamp = sharedDefaults.integer(forKey: streakStartTimestampKey)
        let startTime = (timestamp == 0) ? nil : Date(timeIntervalSince1970: Double(timestamp) / 1000.0)
        
        let label = sharedDefaults.string(forKey: localizedLabelKey) ?? NSLocalizedString("widget_sugarFreeSince", comment: "")
        
        let hasActiveSubscription = sharedDefaults.bool(forKey: subscriptionStatusKey) // Read subscription status
        
        let subscribePrompt = sharedDefaults.string(forKey: subscribePromptKey) ?? NSLocalizedString("widget_subscribeToTrackStreak", comment: "")
        
        return (startTime, label, hasActiveSubscription, subscribePrompt)
    }
}

// --- Timeline Entry ---
struct StreakEntry: TimelineEntry {
    let date: Date // The date for this timeline entry
    let startTime: Date? // The loaded streak start time
    let localizedLabel: String // The localized label from Flutter
    let hasActiveSubscription: Bool // The subscription status
    let subscribePrompt: String
}

// --- SwiftUI View ---
struct StreakWidgetEntryView : View {
    var entry: Provider.Entry
    
    // Environment variable to get widget family (size)
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            // Check subscription status - in debug mode always show streak counter
        #if DEBUG
            streakCounterView
        #else
            if entry.hasActiveSubscription {
                // Show the streak counter for paid users
                streakCounterView
            } else {
                // Show subscription prompt for free users
                subscriptionPromptView
            }
        #endif
        }
        // Add this modifier to make the widget tappable
        .widgetURL(URL(string: "stoppr://home"))
    }
    
    // The original streak counter view for paid users
    var streakCounterView: some View {
        // Calculate duration components based on the entry's start time
        let duration = calculateDuration(from: entry.startTime)

        return VStack(alignment: .center, spacing: 5) { // Reduced spacing for compact view
            // Display the fetched localized label
            Text(entry.localizedLabel)
                .font(.system(size: adaptiveFontSize(for: .caption), weight: .bold))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        
            // Adapt layout based on duration, similar to Flutter widget
            if duration.days > 0 {
                // Days display (localized plural)
                let daysString = String.localizedStringWithFormat(NSLocalizedString("widget_days_count", comment: ""), duration.days)
                Text(daysString)
                    .font(.custom("ElzaRoundVariable-Bold", size: adaptiveFontSize(for: .largeTitle))) // Use custom font & adaptive size
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5) // Allow text to shrink
                    .lineLimit(1)

                // HH:MM display below days (Removed Seconds)
                let hoursAbbrev = NSLocalizedString("widget_hours_abbrev", comment: "")
                let minutesAbbrev = NSLocalizedString("widget_minutes_abbrev", comment: "")
                Text("\(duration.hours)\(hoursAbbrev) \(duration.minutes)\(minutesAbbrev)")
                    .font(.custom("ElzaRoundVariable-Medium", size: adaptiveFontSize(for: .caption))) 
                    .foregroundColor(Color(red: 26/255, green: 26/255, blue: 26/255)) // #1A1A1A solid black
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white) // Solid white background
                    .cornerRadius(15)
            } else if duration.hours > 0 {
                // HHhr MMm display (Removed secondary seconds display)
                let hoursAbbrev = NSLocalizedString("widget_hours_abbrev", comment: "")
                let minutesAbbrev = NSLocalizedString("widget_minutes_abbrev", comment: "")
                Text("\(duration.hours)\(hoursAbbrev) \(duration.minutes)\(minutesAbbrev)")
                    .font(.custom("ElzaRoundVariable-Bold", size: adaptiveFontSize(for: .largeTitle))) // Make this large like the others
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else {
                 // MMm display (Keep this structure for minutes < 60)
                let minutesAbbrev = NSLocalizedString("widget_minutes_abbrev", comment: "")
                Text("\(duration.minutes)\(minutesAbbrev)")
                   .font(.custom("ElzaRoundVariable-Bold", size: adaptiveFontSize(for: .largeTitle)))
                   .foregroundColor(.white)
                   .minimumScaleFactor(0.5)
                   .lineLimit(1)
            }
        }
        .padding(10) // Add padding around the VStack
    }
    
    // Subscription prompt view for free users
    var subscriptionPromptView: some View {
        VStack(alignment: .center, spacing: 8) {
            // Lock icon
            Image(systemName: "lock.fill")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.8))
            
            // Prompt text
            Text(entry.subscribePrompt)
                .font(.custom("ElzaRoundVariable-Medium", size: 14))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
        }
        .padding(10)
    }
    
    // Helper function to calculate duration components
    func calculateDuration(from startTime: Date?) -> (days: Int, hours: Int, minutes: Int, seconds: Int) {
        guard let start = startTime else { return (0, 0, 0, 0) }
        let now = Date()
        // Ensure we don't show negative time if startTime is in the future
        guard now >= start else { return (0, 0, 0, 0) }
        
        let components = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: start, to: now)
        return (components.day ?? 0, components.hour ?? 0, components.minute ?? 0, components.second ?? 0)
    }
    
    // Helper function for adaptive font size based on widget size
    func adaptiveFontSize(for style: Font.TextStyle) -> CGFloat {
        switch family {
        case .systemSmall:
            switch style {
            case .largeTitle: return 30
            case .title: return 26
            case .body: return 18
            case .caption: return 14
            default: return 15
            }
        // Add cases for medium/large if needed later
        default: // Default to small sizes
             switch style {
            case .largeTitle: return 30
            case .title: return 26
            case .body: return 18
            case .caption: return 14
            default: return 15
            }
        }
    }
}

// --- Widget Definition ---
struct StreakWidget: Widget {
    let kind: String = "StreakWidget" // Unique identifier for this widget type

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
             StreakWidgetEntryView(entry: entry)
                .containerBackground(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.929, green: 0.196, blue: 0.447), // #ed3272 - Brand Pink
                            Color(red: 0.992, green: 0.365, blue: 0.196)  // #fd5d32 - Brand Orange
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ), 
                    for: .widget
                )
        }
        .configurationDisplayName(NSLocalizedString("streak_widget_display_name", comment: ""))
        .description(NSLocalizedString("streak_widget_description_ios", comment: ""))
        .supportedFamilies([.systemSmall]) // Only support small widget size for now
    }
}

// --- SwiftUI Preview ---
#Preview(as: .systemSmall) {
    StreakWidget()
} timeline: {
    // Example entries for preview - showing both free and paid scenarios
    StreakEntry(date: Date(), startTime: Calendar.current.date(byAdding: .day, value: -5, to: Date()), localizedLabel: "Sugar-free since:", hasActiveSubscription: true, subscribePrompt: "Subscribe to track your streak") // Paid user with 5 days
    StreakEntry(date: Date(), startTime: Calendar.current.date(byAdding: .hour, value: -3, to: Date()), localizedLabel: "Sugar-free since:", hasActiveSubscription: true, subscribePrompt: "Subscribe to track your streak") // Paid user with 3 hours
    StreakEntry(date: Date(), startTime: nil, localizedLabel: "Sugar-free since:", hasActiveSubscription: false, subscribePrompt: "Subscribe to track your streak") // Free user
}
