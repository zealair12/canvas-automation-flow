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
            
            // More Tab (Modal)
            EmptyView()
                .tabItem {
                    Image(systemName: "ellipsis.circle.fill")
                }
                .tag(5)
        }
        .environmentObject(apiService)
        .background(themeManager.backgroundColor)
        .accentColor(themeManager.accentColor)
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 5 {
                showingMoreModal = true
                selectedTab = 0 // Reset to dashboard
            }
        }
        .sheet(isPresented: $showingMoreModal) {
            MoreOptionsModal(apiService: apiService)
        }
    }
}

struct MoreOptionsModal: View {
    let apiService: APIService
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(themeManager.accentColor)
                    
                    Text("More Options")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.textColor)
                }
                .padding(.top, 20)
                
                // Options Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    // Notifications
                    MoreOptionButton(
                        icon: "bell.fill",
                        title: "Notifications",
                        color: .blue,
                        action: {
                            // Handle notifications
                        }
                    )
                    
                    // Help & Support
                    MoreOptionButton(
                        icon: "questionmark.circle.fill",
                        title: "Help & Support",
                        color: .orange,
                        action: {
                            // Handle help
                        }
                    )
                    
                    // Privacy Policy
                    MoreOptionButton(
                        icon: "doc.text.fill",
                        title: "Privacy Policy",
                        color: .green,
                        action: {
                            // Handle privacy
                        }
                    )
                    
                    // Sign Out
                    MoreOptionButton(
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
                
                // User Info (if authenticated)
                if apiService.isAuthenticated, let user = apiService.user {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.headline)
                                    .foregroundColor(themeManager.textColor)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundColor(themeManager.secondaryTextColor)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(themeManager.surfaceColor)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                }
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

struct MoreOptionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.textColor)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(themeManager.surfaceColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ContentView()
}