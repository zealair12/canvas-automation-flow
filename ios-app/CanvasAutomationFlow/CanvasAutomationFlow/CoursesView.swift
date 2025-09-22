//
//  CoursesView.swift
//  CanvasAutomationFlow
//
//  Created on 2025-09-14.
//

import SwiftUI

struct CoursesView: View {
    @EnvironmentObject var apiService: APIService
    @State private var showingStudyPlan = false
    @State private var selectedCourses: Set<Course> = []
    @State private var studyPlanResponse = ""
    @State private var isLoadingStudyPlan = false
    
    var body: some View {
        NavigationView {
            Group {
                if apiService.isAuthenticated {
                    if apiService.courses.isEmpty {
                        emptyStateView
                    } else {
                        coursesList
                    }
                } else {
                    unauthenticatedView
                }
            }
            .navigationTitle("Courses")
            .refreshable {
                await apiService.fetchCourses()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Study Plan") {
                        selectedCourses = Set(apiService.courses)
                        showingStudyPlan = true
                    }
                    .disabled(apiService.courses.isEmpty)
                }
            }
            .sheet(isPresented: $showingStudyPlan) {
                StudyPlanSheet(
                    selectedCourses: $selectedCourses,
                    response: $studyPlanResponse,
                    isLoading: $isLoadingStudyPlan,
                    apiService: apiService
                )
            }
        }
    }
    
    private var coursesList: some View {
        List(apiService.courses) { course in
            CourseRowView(course: course)
                .onTapGesture {
                    // Navigate to course details
                }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Courses Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your courses will appear here once you're enrolled")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Refresh") {
                Task {
                    await apiService.fetchCourses()
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
            
            Text("Please sign in to view your courses")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct CourseRowView: View {
    let course: Course
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(course.courseCode)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusBadge(status: course.workflowState)
            }
            
            if let description = course.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
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
        case "available": return .green
        case "unpublished": return .orange
        case "completed": return .blue
        default: return .gray
        }
    }
}

struct StudyPlanSheet: View {
    @Binding var selectedCourses: Set<Course>
    @Binding var response: String
    @Binding var isLoading: Bool
    let apiService: APIService
    @Environment(\.dismiss) var dismiss
    @State private var daysAhead = 7
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Courses:")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(selectedCourses)) { course in
                                HStack {
                                    Button(action: {
                                        selectedCourses.remove(course)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    Text(course.name)
                                        .font(.subheadline)
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Study Plan Duration:")
                        .font(.headline)
                    
                    HStack {
                        Text("\(daysAhead) days")
                        Slider(value: Binding(
                            get: { Double(daysAhead) },
                            set: { daysAhead = Int($0) }
                        ), in: 1...30, step: 1)
                    }
                }
                
                Button(action: {
                    Task {
                        await generateStudyPlan()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isLoading ? "Generating..." : "Generate Study Plan")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(selectedCourses.isEmpty || isLoading)
                
                if !response.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("AI Study Plan")
                                .font(.headline)
                            Spacer()
                            Button("Copy") {
                                UIPasteboard.general.string = response
                            }
                            .font(.caption)
                            .foregroundColor(.green)
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
            .navigationTitle("📅 AI Study Plan")
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
    
    private func generateStudyPlan() async {
        let courseIds = selectedCourses.map { $0.canvasCourseId }
        
        isLoading = true
        response = ""
        
        let plan = await apiService.generateStudyPlan(courseIds: courseIds, daysAhead: daysAhead)
        response = plan ?? "Sorry, I couldn't generate a study plan. Please try again."
        
        isLoading = false
    }
}


#Preview {
    CoursesView()
        .environmentObject(APIService())
}
