//
//  ContentView.swift
//  CanvasAutomationFlow
//
//  Created on 2025-09-14.
//

import SwiftUI
import UserNotifications

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
        }
        .environmentObject(apiService)
        .background(themeManager.backgroundColor)
        .accentColor(themeManager.accentColor)
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
    @State private var showingNotificationsSettings = false
    @State private var showingHelpSupport = false
    @State private var showingPrivacyPolicy = false
    @State private var showingAbout = false
    @State private var notificationsEnabled = true
    @State private var assignmentReminders = true
    @State private var dueDateAlerts = true
    
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
                        action: { showingNotificationsSettings = true }
                    )
                    
                    SettingsOptionRow(
                        icon: "questionmark.circle.fill",
                        title: "Help & Support",
                        color: .orange,
                        action: { showingHelpSupport = true }
                    )
                    
                    SettingsOptionRow(
                        icon: "doc.text.fill",
                        title: "Privacy Policy",
                        color: .green,
                        action: { showingPrivacyPolicy = true }
                    )
                    
                    SettingsOptionRow(
                        icon: "info.circle.fill",
                        title: "About",
                        color: .purple,
                        action: { showingAbout = true }
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
        .sheet(isPresented: $showingNotificationsSettings) {
            NotificationsSettingsView(
                notificationsEnabled: $notificationsEnabled,
                assignmentReminders: $assignmentReminders,
                dueDateAlerts: $dueDateAlerts
            )
        }
        .sheet(isPresented: $showingHelpSupport) {
            HelpSupportView()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
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

// MARK: - Notifications Settings View
struct NotificationsSettingsView: View {
    @Binding var notificationsEnabled: Bool
    @Binding var assignmentReminders: Bool
    @Binding var dueDateAlerts: Bool
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Notification Permission Status
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notification Status")
                        .font(.headline)
                        .foregroundColor(themeManager.textColor)
                    
                    HStack {
                        Image(systemName: notificationsEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(notificationsEnabled ? .green : .red)
                        
                        Text(notificationsEnabled ? "Notifications Enabled" : "Notifications Disabled")
                            .foregroundColor(themeManager.textColor)
                    }
                    
                    if !notificationsEnabled {
                        Button("Enable Notifications") {
                            requestNotificationPermission()
                        }
                        .foregroundColor(themeManager.accentColor)
                    }
                }
                .padding()
                .background(themeManager.surfaceColor)
                .cornerRadius(12)
                
                // Notification Types
                VStack(alignment: .leading, spacing: 16) {
                    Text("Notification Types")
                        .font(.headline)
                        .foregroundColor(themeManager.textColor)
                    
                    ToggleRow(
                        title: "Assignment Reminders",
                        subtitle: "Get notified about upcoming assignments",
                        isOn: $assignmentReminders,
                        icon: "doc.text.fill",
                        color: .blue
                    )
                    
                    ToggleRow(
                        title: "Due Date Alerts",
                        subtitle: "Receive alerts 24 hours before due dates",
                        isOn: $dueDateAlerts,
                        icon: "clock.fill",
                        color: .orange
                    )
                }
                .padding()
                .background(themeManager.surfaceColor)
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .background(themeManager.backgroundColor)
            .navigationTitle("Notifications")
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
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                notificationsEnabled = granted
            }
        }
    }
}

// MARK: - Toggle Row Component
struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let icon: String
    let color: Color
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(themeManager.textColor)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(themeManager.accentColor)
        }
    }
}

// MARK: - Help & Support View
struct HelpSupportView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Contact Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Get Help")
                            .font(.headline)
                            .foregroundColor(themeManager.textColor)
                        
                        ContactRow(
                            icon: "envelope.fill",
                            title: "Email Support",
                            subtitle: "okechukwuzealachonu@gmail.com",
                            color: .blue
                        )
                        
                        ContactRow(
                            icon: "phone.fill",
                            title: "Phone Support",
                            subtitle: "+1 (615) 715-5240",
                            color: .green
                        )
                        
                        ContactRow(
                            icon: "questionmark.circle.fill",
                            title: "FAQ",
                            subtitle: "Frequently Asked Questions",
                            color: .orange
                        )
                    }
                    .padding()
                    .background(themeManager.surfaceColor)
                    .cornerRadius(12)
                    
                    // FAQ Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Frequently Asked Questions")
                            .font(.headline)
                            .foregroundColor(themeManager.textColor)
                        
                        FAQItem(
                            question: "How do I connect my Canvas account?",
                            answer: "Go to Settings and enter your Canvas API token. You can find this in your Canvas account under Account Settings > Approved Integrations."
                        )
                        
                        FAQItem(
                            question: "Why aren't my assignments showing up?",
                            answer: "Make sure your Canvas API token has the correct permissions and your courses are published. Try refreshing the app or re-authenticating."
                        )
                        
                        FAQItem(
                            question: "How does the AI help work?",
                            answer: "Our AI assistant uses advanced language models to provide personalized help with assignments, study planning, and concept explanations. It's designed to supplement your learning, not replace it."
                        )
                        
                        FAQItem(
                            question: "Can I use this app offline?",
                            answer: "The app requires an internet connection to sync with Canvas and access AI features. However, previously loaded content remains accessible offline."
                        )
                        
                        FAQItem(
                            question: "Is my data secure?",
                            answer: "Yes, we use industry-standard encryption and follow strict privacy practices. Your Canvas data is only stored locally on your device and never shared with third parties."
                        )
                        
                        FAQItem(
                            question: "How do notifications work?",
                            answer: "The app can send you notifications about upcoming assignment due dates and important course updates. You can customize these in Settings > Notifications."
                        )
                        
                        FAQItem(
                            question: "Can I export my study plan?",
                            answer: "Yes, you can export your study plan as a calendar file (.ics) that can be imported into Google Calendar, Apple Calendar, or any calendar app."
                        )
                        
                        FAQItem(
                            question: "Who developed this app?",
                            answer: "Canvas Automation Flow was developed by Zeal O.A, a passionate developer focused on educational technology. Connect with me on LinkedIn or GitHub for updates and feedback."
                        )
                    }
                    .padding()
                    .background(themeManager.surfaceColor)
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("Help & Support")
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
    }
}

// MARK: - FAQ Item Component
struct FAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(question)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(themeManager.textColor)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(themeManager.accentColor)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(answer)
                    .font(.body)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Contact Row Component
struct ContactRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(themeManager.textColor)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy Policy")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.textColor)
                    
                    Text("Last updated: December 2024")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        PolicySection(
                            title: "Information We Collect",
                            content: "We collect information you provide directly to us, such as when you create an account, use our services, or contact us for support."
                        )
                        
                        PolicySection(
                            title: "How We Use Your Information",
                            content: "We use the information we collect to provide, maintain, and improve our services, process transactions, and communicate with you."
                        )
                        
                        PolicySection(
                            title: "Information Sharing",
                            content: "We do not sell, trade, or otherwise transfer your personal information to third parties without your consent, except as described in this policy."
                        )
                    }
                }
                .padding()
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("Privacy Policy")
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
    }
}

// MARK: - Policy Section Component
struct PolicySection: View {
    let title: String
    let content: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(themeManager.textColor)
            
            Text(content)
                .font(.body)
                .foregroundColor(themeManager.secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // App Icon and Info
                VStack(spacing: 16) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 80))
                        .foregroundColor(themeManager.accentColor)
                    
                    Text("Canvas Automation Flow")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.textColor)
                    
                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                // App Description
                VStack(alignment: .leading, spacing: 12) {
                    Text("About This App")
                        .font(.headline)
                        .foregroundColor(themeManager.textColor)
                    
                    Text("Canvas Automation Flow helps students manage their coursework, assignments, and academic schedule efficiently. Built with SwiftUI and powered by AI assistance.")
                        .font(.body)
                        .foregroundColor(themeManager.secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(themeManager.surfaceColor)
                .cornerRadius(12)
                
                // Developer Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Developer")
                        .font(.headline)
                        .foregroundColor(themeManager.textColor)
                    
                    Text("Developed by Zeal O.A")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(themeManager.textColor)
                    
                    Text("Passionate developer focused on educational technology and AI-powered solutions.")
                        .font(.body)
                        .foregroundColor(themeManager.secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 20) {
                        Link(destination: URL(string: "https://www.linkedin.com/in/okechukwuzealachonu/")!) {
                            HStack(spacing: 8) {
                                Image(systemName: "link")
                                    .foregroundColor(.blue)
                                Text("LinkedIn")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Link(destination: URL(string: "https://github.com/zealair12")!) {
                            HStack(spacing: 8) {
                                Image(systemName: "link")
                                    .foregroundColor(.purple)
                                Text("GitHub")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(themeManager.surfaceColor)
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .background(themeManager.backgroundColor)
            .navigationTitle("About")
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
    }
}

#Preview {
    ContentView()
}