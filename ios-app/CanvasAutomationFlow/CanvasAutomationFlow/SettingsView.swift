//
//  SettingsView.swift
//  CanvasAutomationFlow
//
//  Created on 2025-09-14.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var apiService: APIService
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationView {
            List {
                if apiService.isAuthenticated {
                    userSection
                    notificationSection
                    appSection
                    logoutSection
                } else {
                    signInSection
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    apiService.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    private var userSection: some View {
        Section("User") {
            if let user = apiService.user {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text(user.name)
                            .font(.headline)
                        Text(user.email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Role")
                    Spacer()
                    Text(user.role.capitalized)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var notificationSection: some View {
        Section("Notifications") {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.blue)
                    .frame(width: 20)
                Text("Push Notifications")
                Spacer()
                Toggle("", isOn: .constant(true))
            }
            
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.green)
                    .frame(width: 20)
                Text("Email Notifications")
                Spacer()
                Toggle("", isOn: .constant(false))
            }
            
            HStack {
                Image(systemName: "message.fill")
                    .foregroundColor(.purple)
                    .frame(width: 20)
                Text("SMS Notifications")
                Spacer()
                Toggle("", isOn: .constant(false))
            }
        }
    }
    
    private var appSection: some View {
        Section("App") {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .frame(width: 20)
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.orange)
                    .frame(width: 20)
                Text("Help & Support")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.green)
                    .frame(width: 20)
                Text("Privacy Policy")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var logoutSection: some View {
        Section {
            Button("Sign Out") {
                showingLogoutAlert = true
            }
            .foregroundColor(.red)
        }
    }
    
    private var signInSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                
                Text("Sign In Required")
                    .font(.headline)
                
                Text("Please sign in to access your settings")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(APIService())
}
