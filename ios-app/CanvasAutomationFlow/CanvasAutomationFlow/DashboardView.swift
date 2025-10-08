//
//  DashboardView.swift
//  CanvasAutomationFlow
//
//  Created on 2025-09-14.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var apiService: APIService
    @State private var showingAuth = false
    @State private var showingConceptExplainer = false
    @State private var concept = ""
    @State private var conceptResponse = ""
    @State private var isLoadingConcept = false
    
    var body: some View {
        NavigationView {
            if apiService.isAuthenticated {
                authenticatedView
            } else {
                unauthenticatedView
            }
        }
        .sheet(isPresented: $showingAuth) {
            AuthenticationView()
        }
    }
    
    private var authenticatedView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Welcome Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome back!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let user = apiService.user {
                        Text(user.name)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Quick Stats
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(
                        title: "Courses",
                        value: "\(apiService.courses.count)",
                        icon: "book.fill",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Assignments",
                        value: "\(apiService.assignments.count)",
                        icon: "doc.text.fill",
                        color: .green
                    )
                    
                    StatCard(
                        title: "Due Soon",
                        value: "\(apiService.assignments.filter { $0.isDueSoon }.count)",
                        icon: "clock.fill",
                        color: .orange
                    )
                    
                    StatCard(
                        title: "Overdue",
                        value: "\(apiService.assignments.filter { $0.isOverdue }.count)",
                        icon: "exclamationmark.triangle.fill",
                        color: .red
                    )
                }
                .padding(.horizontal)
                
                // AI Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("AI Quick Actions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Button(action: {
                        showingConceptExplainer = true
                    }) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.orange)
                            Text("Explain Any Concept")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                }
                
                // Recent Reminders
                if !apiService.reminders.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Reminders")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(apiService.reminders.prefix(3)) { reminder in
                            ReminderRowView(reminder: reminder)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Dashboard")
        .refreshable {
            await loadUserData()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                UserAvatarButton(apiService: apiService)
            }
        }
        .task {
            if apiService.isAuthenticated {
                await loadUserData()
            }
        }
        .sheet(isPresented: $showingConceptExplainer) {
            ConceptExplainerSheet(
                concept: $concept,
                response: $conceptResponse,
                isLoading: $isLoadingConcept,
                apiService: apiService
            )
        }
    }
    
    private var unauthenticatedView: some View {
        VStack(spacing: 30) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("Canvas Automation Flow")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Stay on top of your assignments with AI-powered reminders and feedback")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            Button("Sign In with Canvas") {
                showingAuth = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
    
    private func loadUserData() async {
        await apiService.fetchUserProfile()
        await apiService.fetchCourses()
        await apiService.fetchAllAssignments()
        await apiService.fetchReminders()
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AssignmentRowView: View {
    let assignment: Assignment
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.name)
                    .font(.headline)
                    .lineLimit(2)
                
                if let dueAt = assignment.dueAt {
                    Text(formatDate(dueAt))
                        .font(.caption)
                        .foregroundColor(assignment.isOverdue ? .red : .secondary)
                }
            }
            
            Spacer()
            
            if assignment.isOverdue {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            } else if assignment.isDueSoon {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

struct ReminderRowView: View {
    let reminder: Reminder
    
    var body: some View {
        HStack {
            Image(systemName: "bell.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.message)
                    .font(.body)
                    .lineLimit(2)
                
                Text(formatDate(reminder.scheduledFor))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(reminder.status.capitalized)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.2))
                .foregroundColor(statusColor)
                .cornerRadius(4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private var statusColor: Color {
        switch reminder.status {
        case "sent": return .green
        case "pending": return .orange
        case "failed": return .red
        default: return .gray
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

struct ConceptExplainerSheet: View {
    @Binding var concept: String
    @Binding var response: String
    @Binding var isLoading: Bool
    let apiService: APIService
    @Environment(\.dismiss) var dismiss
    @State private var selectedLevel = "undergraduate"
    @State private var context = ""
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Concept to Explain:")
                        .font(.headline)
                    TextField("Enter any concept", text: $concept)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Additional Context (Optional):")
                        .font(.headline)
                    TextField("Any additional context", text: $context, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(2...4)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Explanation Level:")
                        .font(.headline)
                    Picker("Level", selection: $selectedLevel) {
                        Text("Beginner").tag("beginner")
                        Text("Undergraduate").tag("undergraduate")
                        Text("Graduate").tag("graduate")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Button(action: {
                    Task {
                        await explainConcept()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isLoading ? "Explaining..." : "Explain Concept")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(concept.isEmpty || isLoading)
                
                if !response.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("AI Explanation")
                                .font(.headline)
                            Spacer()
                            Button("Copy") {
                                UIPasteboard.general.string = response
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                        }
                        
                        ScrollView {
                            MathFormattedText(response)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Explain Any Concept")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func explainConcept() async {
        isLoading = true
        response = ""
        
        let explanation = await apiService.explainConcept(
            concept: concept,
            context: context,
            level: selectedLevel
        )
        
        response = explanation ?? "Sorry, I couldn't explain this concept. Please try again."
        isLoading = false
    }
}


// MARK: - Shared FormattedText Component
struct FormattedText: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        // Use SwiftUI's native Markdown support directly
        // The AI now returns proper Markdown formatting
        if let attributedString = try? AttributedString(markdown: text) {
            Text(attributedString)
        } else {
            // Fallback to plain text if Markdown parsing fails
            Text(text)
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(APIService())
}
