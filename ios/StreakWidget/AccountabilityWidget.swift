//
//  AccountabilityWidget.swift
//  StreakWidget
//
//  Accountability partner widget showing both users' recovery progress
//

import WidgetKit
import SwiftUI

// Timeline Provider for Accountability Widget
struct AccountabilityProvider: TimelineProvider {
    func placeholder(in context: Context) -> AccountabilityEntry {
        AccountabilityEntry(
            date: Date(),
            myName: "Me",
            myDays: 5,
            myPercentage: 5,
            partnerName: "Alex",
            partnerDays: 2,
            partnerPercentage: 2,
            localizedTitle: NSLocalizedString("widget_accountability_title", comment: ""),
            localizedDaysSuffix: NSLocalizedString("widget_days_suffix", comment: ""),
            hasPartner: true
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (AccountabilityEntry) -> ()) {
        let data = getAccountabilityData()
        completion(data)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<AccountabilityEntry>) -> ()) {
        let currentDate = Date()
        let data = getAccountabilityData()
        
        let entry = AccountabilityEntry(
            date: currentDate,
            myName: data.myName,
            myDays: data.myDays,
            myPercentage: data.myPercentage,
            partnerName: data.partnerName,
            partnerDays: data.partnerDays,
            partnerPercentage: data.partnerPercentage,
            localizedTitle: data.localizedTitle,
            localizedDaysSuffix: data.localizedDaysSuffix,
            hasPartner: data.hasPartner
        )
        
        // Update every 15 minutes
        let nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        completion(timeline)
    }
    
    private func getAccountabilityData() -> AccountabilityEntry {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return AccountabilityEntry.noPartner()
        }
        
        #if DEBUG
        // DEBUG MODE: Always show fake partner data for testing
        return AccountabilityEntry(
            date: Date(),
            myName: "Sarah",
            myDays: 5,
            myPercentage: 5,
            partnerName: "Alex",
            partnerDays: 12,
            partnerPercentage: 13,
            localizedTitle: NSLocalizedString("widget_accountability_title", comment: ""),
            localizedDaysSuffix: NSLocalizedString("widget_days_suffix", comment: ""),
            hasPartner: true
        )
        #else
        let hasPartner = sharedDefaults.bool(forKey: "accountability_has_partner")
        
        if !hasPartner {
            return AccountabilityEntry.noPartner()
        }
        
        let myName = sharedDefaults.string(forKey: "accountability_my_name") ?? "Me"
        let myDays = sharedDefaults.integer(forKey: "accountability_my_days")
        let myPercentage = sharedDefaults.integer(forKey: "accountability_my_percentage")
        
        let partnerName = sharedDefaults.string(forKey: "accountability_partner_name") ?? "Partner"
        let partnerDays = sharedDefaults.integer(forKey: "accountability_partner_days")
        let partnerPercentage = sharedDefaults.integer(forKey: "accountability_partner_percentage")
        
        let localizedTitle = sharedDefaults.string(forKey: "accountability_localized_title") ?? NSLocalizedString("widget_accountability_title", comment: "")
        let localizedDaysSuffix = sharedDefaults.string(forKey: "accountability_localized_days_suffix") ?? NSLocalizedString("widget_days_suffix", comment: "")
        
        return AccountabilityEntry(
            date: Date(),
            myName: myName,
            myDays: myDays,
            myPercentage: myPercentage,
            partnerName: partnerName,
            partnerDays: partnerDays,
            partnerPercentage: partnerPercentage,
            localizedTitle: localizedTitle,
            localizedDaysSuffix: localizedDaysSuffix,
            hasPartner: true
        )
        #endif
    }
}

// Timeline Entry
struct AccountabilityEntry: TimelineEntry {
    let date: Date
    let myName: String
    let myDays: Int
    let myPercentage: Int
    let partnerName: String
    let partnerDays: Int
    let partnerPercentage: Int
    let localizedTitle: String
    let localizedDaysSuffix: String
    let hasPartner: Bool
    
    static func noPartner() -> AccountabilityEntry {
        return AccountabilityEntry(
            date: Date(),
            myName: "Me",
            myDays: 0,
            myPercentage: 0,
            partnerName: "Partner",
            partnerDays: 0,
            partnerPercentage: 0,
            localizedTitle: NSLocalizedString("widget_accountability_title", comment: ""),
            localizedDaysSuffix: NSLocalizedString("widget_days_suffix", comment: ""),
            hasPartner: false
        )
    }
}

// SwiftUI View
struct AccountabilityWidgetEntryView: View {
    var entry: AccountabilityProvider.Entry
    
    var body: some View {
        if !entry.hasPartner {
            // Show message to find partner first
            VStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(red: 237/255, green: 50/255, blue: 114/255))
                
                Text(NSLocalizedString("widget_accountability_no_partner_title", comment: ""))
                    .font(.custom("ElzaRoundVariable-Bold", size: 16))
                    .foregroundColor(Color(red: 26/255, green: 26/255, blue: 26/255))
                    .multilineTextAlignment(.center)
                
                Text(NSLocalizedString("widget_accountability_no_partner_subtitle", comment: ""))
                    .font(.custom("ElzaRoundVariable-Medium", size: 13))
                    .foregroundColor(Color(red: 102/255, green: 102/255, blue: 102/255))
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .widgetURL(URL(string: "stoppr://accountability"))
        } else {
            HStack(spacing: 0) {
                // Left side - Me
                recoveryRingView(
                    name: entry.myName,
                    days: entry.myDays,
                    percentage: entry.myPercentage,
                    localizedTitle: entry.localizedTitle,
                    localizedDaysSuffix: entry.localizedDaysSuffix
                )
                .frame(maxWidth: .infinity)
                
                // Vertical separator
                Rectangle()
                    .fill(Color(red: 0.878, green: 0.878, blue: 0.878)) // #E0E0E0
                    .frame(width: 1)
                
                // Right side - Partner
                recoveryRingView(
                    name: entry.partnerName,
                    days: entry.partnerDays,
                    percentage: entry.partnerPercentage,
                    localizedTitle: entry.localizedTitle,
                    localizedDaysSuffix: entry.localizedDaysSuffix
                )
                .frame(maxWidth: .infinity)
            }
            .widgetURL(URL(string: "stoppr://accountability"))
        }
    }
    
    func recoveryRingView(name: String, days: Int, percentage: Int, localizedTitle: String, localizedDaysSuffix: String) -> some View {
        VStack(spacing: 8) {
            // Name at top
            Text(name)
                .font(.custom("ElzaRoundVariable-Bold", size: 14))
                .foregroundColor(Color(red: 26/255, green: 26/255, blue: 26/255))
                .lineLimit(1)
            
            // Recovery ring
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color(red: 224/255, green: 224/255, blue: 224/255), lineWidth: 8)
                    .frame(width: 100, height: 100)
                
                // Progress arc
                Circle()
                    .trim(from: 0, to: min(CGFloat(percentage) / 100.0, 1.0))
                    .stroke(Color(red: 237/255, green: 50/255, blue: 114/255), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                
                // Content inside ring
                VStack(spacing: 2) {
                    // "RECOVERY" text
                    Text(localizedTitle.uppercased())
                        .font(.custom("ElzaRoundVariable-Bold", size: 9))
                        .foregroundColor(Color(red: 26/255, green: 26/255, blue: 26/255))
                        .lineLimit(1)
                    
                    // Percentage
                    Text("\(percentage)%")
                        .font(.custom("ElzaRoundVariable-Bold", size: 24))
                        .foregroundColor(Color(red: 26/255, green: 26/255, blue: 26/255))
                    
                    // Days text
                    Text("\(days) \(localizedDaysSuffix)")
                        .font(.custom("ElzaRoundVariable-Medium", size: 10))
                        .foregroundColor(Color(red: 102/255, green: 102/255, blue: 102/255))
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
    }
}

// Widget Definition
struct AccountabilityWidget: Widget {
    let kind: String = "AccountabilityWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AccountabilityProvider()) { entry in
            AccountabilityWidgetEntryView(entry: entry)
                .containerBackground(Color.white, for: .widget)
        }
        .configurationDisplayName(NSLocalizedString("accountability_widget_display_name", comment: ""))
        .description(NSLocalizedString("accountability_widget_description", comment: ""))
        .supportedFamilies([.systemMedium]) // Rectangular widget for two-column layout
    }
}

// SwiftUI Preview
#Preview(as: .systemMedium) {
    AccountabilityWidget()
} timeline: {
    AccountabilityEntry(
        date: Date(),
        myName: "Sarah",
        myDays: 5,
        myPercentage: 5,
        partnerName: "Alex",
        partnerDays: 2,
        partnerPercentage: 2,
        localizedTitle: "Recovery",
        localizedDaysSuffix: "Days",
        hasPartner: true
    )
    AccountabilityEntry(
        date: Date(),
        myName: "Emma",
        myDays: 45,
        myPercentage: 50,
        partnerName: "Lisa",
        partnerDays: 30,
        partnerPercentage: 33,
        localizedTitle: "Recovery",
        localizedDaysSuffix: "Days",
        hasPartner: true
    )
}

