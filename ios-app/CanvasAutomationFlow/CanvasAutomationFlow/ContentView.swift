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
                }
                .tag(0)
            
            // Courses Tab
            CoursesView()
                .tabItem {
                    Image(systemName: "book.closed.fill")
                }
                .tag(1)
            
            // Assignments Tab
            AssignmentsView()
                .tabItem {
                    Image(systemName: "doc.text.fill")
                }
                .tag(2)
            
            // Files Tab
            FilesView()
                .tabItem {
                    Image(systemName: "folder.fill")
                }
                .tag(3)
            
            // AI Assistant Tab
            AIAssistantView()
                .tabItem {
                    Image(systemName: "wand.and.stars")
                }
                .tag(4)
            
            // Settings Tab (More)
            SettingsView()
                .tabItem {
                    Image(systemName: "ellipsis.circle.fill")
                }
                .tag(5)
        }
        .environmentObject(apiService)
        .background(themeManager.backgroundColor)
        .accentColor(themeManager.accentColor)
    }
}

#Preview {
    ContentView()
}