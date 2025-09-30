//
//  CanvasAutomationFlowApp.swift
//  CanvasAutomationFlow
//
//  Created by HP on 15/09/2025.
//

import SwiftUI

@main
struct CanvasAutomationFlowApp: App {
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .preferredColorScheme(.dark)
        }
    }
}
