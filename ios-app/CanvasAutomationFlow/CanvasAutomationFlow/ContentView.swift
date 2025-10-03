//
//  ContentView.swift
//  CanvasAutomationFlow
//
//  Created on 2025-09-14.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var apiService = APIService()
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            DashboardView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Dashboard")
                }
                .tag(0)
            
            // Courses Tab
            CoursesView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("Courses")
                }
                .tag(1)
            
            // Assignments Tab
            AssignmentsView()
                .tabItem {
                    Image(systemName: "doc.text.fill")
                    Text("Assignments")
                }
                .tag(2)
            
            // Files Tab
            FilesView()
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("Files")
                }
                .tag(3)
            
            // AI Assistant Tab
            AIAssistantView()
                .tabItem {
                    Image(systemName: "sparkles")
                    Text("AI Assistant")
                }
                .tag(4)
            
            // Reminders Tab
            RemindersView()
                .tabItem {
                    Image(systemName: "bell.fill")
                    Text("Reminders")
                }
                .tag(5)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("More")
                }
                .tag(6)
        }
        .environmentObject(apiService)
        .background(themeManager.backgroundColor)
        .accentColor(themeManager.accentColor)
    }
}

#Preview {
    ContentView()
}