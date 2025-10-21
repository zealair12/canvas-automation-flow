//
//  AssignmentsView.swift
//  CanvasAutomationFlow
//
//  Created on 2025-09-14.
//

import SwiftUI

struct AssignmentsView: View {
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedFilter: AssignmentFilter = .all
    @State private var showingAIHelp = false
    @State private var selectedAssignmentForAI: Assignment?
    @State private var aiQuestion = ""
    @State private var aiResponse = ""
    @State private var isLoadingAI = false
    @State private var searchText = ""
    
    enum AssignmentFilter: String, CaseIterable {
        case all = "All"
        case dueSoon = "Due Soon"
        case overdue = "Overdue"
        case completed = "Completed"
    }
    
    var filteredAssignments: [Assignment] {
        let filterByStatus: [Assignment]
        switch selectedFilter {
        case .all:
            filterByStatus = apiService.assignments
        case .dueSoon:
            filterByStatus = apiService.assignments.filter { $0.isDueSoon && !$0.isOverdue }
        case .overdue:
            filterByStatus = apiService.assignments.filter { $0.isOverdue }
        case .completed:
            filterByStatus = apiService.assignments.filter { $0.status == "graded" }
        }
        
        // Apply search filter
        if searchText.isEmpty {
            return filterByStatus
        } else {
            return filterByStatus.filter { assignment in
                assignment.name.localizedCaseInsensitiveContains(searchText) ||
                (assignment.description ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if apiService.isAuthenticated {
                    if apiService.assignments.isEmpty {
                        emptyStateView
                    } else {
                        assignmentsList
                    }
                } else {
                    unauthenticatedView
                }
            }
            .navigationTitle("Assignments")
            .refreshable {
                await loadAssignments()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(AssignmentFilter.allCases, id: \.self) { filter in
                            Button(filter.rawValue) {
                                selectedFilter = filter
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAIHelp) {
                AIHelpSheet(
                    assignment: selectedAssignmentForAI,
                    question: $aiQuestion,
                    response: $aiResponse,
                    isLoading: $isLoadingAI,
                    apiService: apiService
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private var assignmentsList: some View {
        VStack(spacing: 0) {
            // Search Bar
            SearchBarView(text: $searchText, placeholder: "Search assignments...")
                .padding()
            
            List(filteredAssignments) { assignment in
            NavigationLink(destination: AssignmentDetailView(assignment: assignment)) {
                AssignmentDetailRowView(assignment: assignment)
            }
            .swipeActions(edge: .trailing) {
                Button("AI Help") {
                    showAIHelp(for: assignment)
                }
                .tint(.purple)
                
                Button("Remind") {
                    createReminder(for: assignment)
                }
                .tint(.blue)
            }
        }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Assignments Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your assignments will appear here once they're available")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Refresh") {
                Task {
                    await loadAssignments()
                }
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
            
            Text("Please sign in to view your assignments")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private func createReminder(for assignment: Assignment) {
        Task {
            await apiService.createReminder(assignmentId: assignment.canvasAssignmentId, courseId: assignment.courseId, hoursBeforeDue: 24)
        }
    }
    
    private func showAIHelp(for assignment: Assignment) {
        selectedAssignmentForAI = assignment
        aiQuestion = ""
        aiResponse = ""
        showingAIHelp = true
    }
    
    private func loadAssignments() async {
        // Load assignments from all courses
        await apiService.fetchAllAssignments()
    }
}

struct AssignmentDetailRowView: View {
    let assignment: Assignment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.name)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if let course = findCourse(for: assignment) {
                        Text(course.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                AssignmentStatusBadge(assignment: assignment)
            }
            
            if let description = assignment.description, !description.isEmpty {
                Text(stripHTML(description))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                if let dueAt = assignment.dueAt {
                    Label(formatDate(dueAt), systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(assignment.isOverdue ? .red : .secondary)
                }
                
                Spacer()
                
                if let points = assignment.pointsPossible {
                    Label("\(Int(points)) pts", systemImage: "star")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func findCourse(for assignment: Assignment) -> Course? {
        // This would typically be handled by the API service
        return nil
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
    
    private func stripHTML(_ html: String) -> String {
        // Remove HTML tags and decode entities
        var result = html
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }
}

struct AssignmentStatusBadge: View {
    let assignment: Assignment
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.caption)
            
            Text(statusText)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2))
        .foregroundColor(statusColor)
        .cornerRadius(4)
    }
    
    private var statusIcon: String {
        if assignment.isOverdue {
            return "exclamationmark.triangle.fill"
        } else if assignment.isDueSoon {
            return "clock.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }
    
    private var statusText: String {
        if assignment.isOverdue {
            return "Overdue"
        } else if assignment.isDueSoon {
            return "Due Soon"
        } else {
            return "On Track"
        }
    }
    
    private var statusColor: Color {
        if assignment.isOverdue {
            return .red
        } else if assignment.isDueSoon {
            return .orange
        } else {
            return .green
        }
    }
}

struct AIHelpSheet: View {
    let assignment: Assignment?
    @Binding var question: String
    @Binding var response: String
    @Binding var isLoading: Bool
    let apiService: APIService
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                if let assignment = assignment {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Assignment: \(assignment.name)")
                            .font(.headline)
                        if let points = assignment.pointsPossible {
                            Text("\(Int(points)) points")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Question:")
                        .font(.headline)
                    TextField("What do you need help with?", text: $question, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                
                Button(action: {
                    Task {
                        await getAIHelp()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isLoading ? "Getting Help..." : "Get AI Help")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(question.isEmpty || isLoading)
                
                if !response.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("AI Response")
                                .font(.headline)
                            Spacer()
                            Button("Copy") {
                                UIPasteboard.general.string = response
                            }
                            .font(.caption)
                            .foregroundColor(.purple)
                        }
                        
                        ScrollView([.vertical, .horizontal], showsIndicators: true) {
                            MarkdownView(content: response, sources: nil, backgroundColor: themeManager.surfaceColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .background(themeManager.surfaceColor)
                                .cornerRadius(8)
                                .frame(minWidth: 300, minHeight: 300)
                        }
                        .frame(maxHeight: 600)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("AI Assignment Help")
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
    
    private func getAIHelp() async {
        guard let assignment = assignment else { return }
        
        // Validate question is not empty
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            response = "Please enter your question first."
            return
        }
        
        isLoading = true
        response = ""
        
        print("🔍 Getting AI help for assignment: \(assignment.canvasAssignmentId) in course: \(assignment.courseId)")
        print("📝 Question: \(question)")
        
        // Use unified endpoint with optional files (none here) for consistency
        let helpResult = await apiService.getAssignmentHelpWithFiles(
            assignmentId: assignment.canvasAssignmentId,
            courseId: assignment.courseId,
            question: question,
            files: [],
            helpType: "guidance"  // Quick help from swipe action
        )
        
        if let result = helpResult {
            print("✅ Received AI response")
            response = result.content
        } else {
            print("❌ Failed to get AI response")
            response = "Unable to get AI help. Please check:\n• Network connection\n• Assignment exists in Canvas\n• Backend server is running\n\nTry again or contact support."
        }
        
        isLoading = false
    }
}


#Preview {
    AssignmentsView()
        .environmentObject(APIService())
}
