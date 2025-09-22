//
//  RemindersView.swift
//  CanvasAutomationFlow
//
//  Created on 2025-09-14.
//

import SwiftUI

struct RemindersView: View {
    @EnvironmentObject var apiService: APIService
    @State private var showingCreateReminder = false
    
    var body: some View {
        NavigationView {
            Group {
                if apiService.isAuthenticated {
                    if apiService.reminders.isEmpty {
                        emptyStateView
                    } else {
                        remindersList
                    }
                } else {
                    unauthenticatedView
                }
            }
            .navigationTitle("Reminders")
            .refreshable {
                await loadReminders()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        showingCreateReminder = true
                    }
                    .disabled(!apiService.isAuthenticated)
                }
            }
            .sheet(isPresented: $showingCreateReminder) {
                CreateReminderView()
            }
        }
    }
    
    private var remindersList: some View {
        List(apiService.reminders) { reminder in
            ReminderDetailRowView(reminder: reminder)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Reminders")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create reminders to stay on top of your assignments")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Create Reminder") {
                showingCreateReminder = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var unauthenticatedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Sign In Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Please sign in to manage your reminders")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private func loadReminders() async {
        // For now, we don't have a specific reminders endpoint
        // In a real implementation, you would fetch reminders from the backend
        // This is a placeholder method
    }
}

struct ReminderDetailRowView: View {
    let reminder: Reminder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.message)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(formatDate(reminder.scheduledFor))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ReminderStatusBadge(status: reminder.status)
            }
        }
        .padding(.vertical, 4)
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

struct ReminderStatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(4)
    }
    
    private var statusColor: Color {
        switch status {
        case "sent": return .green
        case "pending": return .orange
        case "failed": return .red
        default: return .gray
        }
    }
}

struct CreateReminderView: View {
    @EnvironmentObject var apiService: APIService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAssignment: Assignment?
    @State private var hoursBeforeDue = 24
    
    var body: some View {
        NavigationView {
            Form {
                Section("Assignment") {
                    Picker("Select Assignment", selection: $selectedAssignment) {
                        Text("Choose an assignment").tag(nil as Assignment?)
                        ForEach(apiService.assignments) { assignment in
                            Text(assignment.name).tag(assignment as Assignment?)
                        }
                    }
                }
                
                Section("Reminder Time") {
                    Stepper("\(hoursBeforeDue) hours before due", value: $hoursBeforeDue, in: 1...168)
                }
                
                Section {
                    Button("Create Reminder") {
                        if let assignment = selectedAssignment {
                            Task {
                                await apiService.createReminder(assignmentId: assignment.canvasAssignmentId, courseId: assignment.courseId, hoursBeforeDue: hoursBeforeDue)
                                dismiss()
                            }
                        }
                    }
                    .disabled(selectedAssignment == nil)
                }
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    RemindersView()
        .environmentObject(APIService())
}
