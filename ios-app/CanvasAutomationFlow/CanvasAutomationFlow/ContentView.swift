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
    @State private var showingMoreModal = false
    
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
        }
        .environmentObject(apiService)
        .background(themeManager.backgroundColor)
        .accentColor(themeManager.accentColor)
        .overlay(alignment: .topLeading) {
            UserAvatarButton(apiService: apiService)
                .padding(.top, 10)
                .padding(.leading, 20)
        }
    }
}

struct UserAvatarButton: View {
    let apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingSettingsModal = false
    
    var body: some View {
        Button(action: {
            showingSettingsModal = true
        }) {
            if let user = apiService.user {
                UserAvatarView(user: user)
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
        .sheet(isPresented: $showingSettingsModal) {
            SettingsModal(apiService: apiService)
        }
    }
}

struct UserAvatarView: View {
    let user: User
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Text(userInitials)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .background(userColor)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 2)
            )
    }
    
    private var userInitials: String {
        let names = user.name.split(separator: " ")
        if names.count >= 2 {
            return String(names[0].prefix(1) + names[1].prefix(1)).uppercased()
        } else if names.count == 1 {
            return String(names[0].prefix(2)).uppercased()
        }
        return "U"
    }
    
    private var userColor: Color {
        // Generate consistent color based on user name hash
        let hash = user.name.hash
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .red, .pink, .teal, .indigo, .mint, .cyan
        ]
        let index = abs(hash) % colors.count
        return colors[index]
    }
}

struct SettingsModal: View {
    let apiService: APIService
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // User Info Header
                if let user = apiService.user {
                    VStack(spacing: 12) {
                        UserAvatarView(user: user)
                            .scaleEffect(1.5)
                        
                        VStack(spacing: 4) {
                            Text(user.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.textColor)
                            
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                    }
                    .padding(.top, 20)
                }
                
                // Settings Options
                VStack(spacing: 12) {
                    SettingsOptionRow(
                        icon: "bell.fill",
                        title: "Notifications",
                        color: .blue,
                        action: {}
                    )
                    
                    SettingsOptionRow(
                        icon: "questionmark.circle.fill",
                        title: "Help & Support",
                        color: .orange,
                        action: {}
                    )
                    
                    SettingsOptionRow(
                        icon: "doc.text.fill",
                        title: "Privacy Policy",
                        color: .green,
                        action: {}
                    )
                    
                    SettingsOptionRow(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: "Sign Out",
                        color: .red,
                        action: {
                            showingLogoutAlert = true
                        }
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .background(themeManager.backgroundColor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.accentColor)
                }
            }
        }
        .alert("Sign Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                apiService.signOut()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

struct SettingsOptionRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(themeManager.textColor)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(themeManager.surfaceColor)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ContentView()
}