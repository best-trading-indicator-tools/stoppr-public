//
//  StreakWidgetBundle.swift
//  StreakWidget
//
//  Created by David Attias on 03/05/2025.
//

import WidgetKit
import SwiftUI

@main
struct StreakWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        AccountabilityWidget()
        PledgeWidget()
        PanicWidget()
        QuickMeditationWidget()
    }
}
