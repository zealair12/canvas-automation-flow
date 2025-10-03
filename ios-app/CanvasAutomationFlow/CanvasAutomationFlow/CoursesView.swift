//
//  CoursesView.swift
//  CanvasAutomationFlow
//
//  Created on 2025-09-14.
//

import SwiftUI

struct CoursesView: View {
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingStudyPlan = false
    @State private var selectedCourses: Set<Course> = []
    @State private var studyPlanResponse = ""
    @State private var isLoadingStudyPlan = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            Group {
                if apiService.isAuthenticated {
                    if apiService.courses.isEmpty && apiService.coursesByTerm.isEmpty {
                        emptyStateView
                    } else {
                        coursesList
                    }
                } else {
                    unauthenticatedView
                }
            }
            .navigationTitle("Courses")
            .futuristicFont(.futuristicTitle)
            .foregroundColor(themeManager.textColor)
            .background(themeManager.backgroundColor)
            .refreshable {
                await apiService.fetchCourses()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    FuturisticButton(title: "Study Plan") {
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
        .background(themeManager.backgroundColor)
    }
    
    // Filtered courses by search text
    private var filteredCoursesByTerm: [String: [Course]] {
        if searchText.isEmpty {
            return apiService.coursesByTerm
        } else {
            var filtered: [String: [Course]] = [:]
            for (term, courses) in apiService.coursesByTerm {
                let matchingCourses = courses.filter { course in
                    course.name.localizedCaseInsensitiveContains(searchText) ||
                    course.courseCode.localizedCaseInsensitiveContains(searchText)
                }
                if !matchingCourses.isEmpty {
                    filtered[term] = matchingCourses
                }
            }
            return filtered
        }
    }
    
    private var coursesList: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Search Bar
                SearchBarView(text: $searchText, placeholder: "Search courses...")
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                LazyVStack(spacing: 16) {
                    ForEach(filteredCoursesByTerm.keys.sorted(), id: \.self) { term in
                        VStack(alignment: .leading, spacing: 8) {
                            // Term Header
                            HStack {
                                Text(term)
                                    .futuristicFont(.futuristicHeadline)
                                    .foregroundColor(themeManager.accentColor)
                                
                                Spacer()
                                
                                Text("\(filteredCoursesByTerm[term]?.count ?? 0) courses")
                                    .futuristicFont(.futuristicCaption)
                                    .foregroundColor(themeManager.secondaryTextColor)
                            }
                            .padding(.horizontal)
                            
                            // Courses in this term
                            LazyVStack(spacing: 8) {
                                ForEach(filteredCoursesByTerm[term] ?? []) { course in
                                    NavigationLink(destination: CourseDetailView(course: course)) {
                                        CourseRowView(course: course)
                                            .futuristicCard()
                                            .glowingBorder()
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(themeManager.backgroundColor)
        .onAppear {
            print("🔍 CoursesView - Total courses: \(apiService.courses.count)")
            print("🔍 CoursesView - Terms: \(apiService.coursesByTerm.keys.sorted())")
            print("🔍 CoursesView - coursesByTerm isEmpty: \(apiService.coursesByTerm.isEmpty)")
            print("🔍 CoursesView - courses isEmpty: \(apiService.courses.isEmpty)")
            for (term, courses) in apiService.coursesByTerm {
                print("🔍 Term '\(term)': \(courses.count) courses")
                for course in courses {
                    print("  - \(course.name)")
                }
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
                .foregroundColor(themeManager.textColor)
            
            Text("Your courses will appear here once you're enrolled")
                .font(.body)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
            
            Button("Refresh") {
                Task {
                    await apiService.fetchCourses()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(themeManager.backgroundColor)
    }
    
    private var unauthenticatedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Sign In Required")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.textColor)
            
            Text("Please sign in to view your courses")
                .font(.body)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(themeManager.backgroundColor)
    }
}

struct CourseRowView: View {
    let course: Course
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name)
                        .font(.headline)
                        .foregroundColor(themeManager.textColor)
                        .lineLimit(2)
                    
                    Text(course.courseCode)
                        .font(.subheadline)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                Spacer()
                
                StatusBadge(status: course.workflowState)
            }
            
            if let description = course.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: String
    @EnvironmentObject var themeManager: ThemeManager
    
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
        default: return themeManager.secondaryTextColor
        }
    }
}

struct StudyPlanSheet: View {
    @Binding var selectedCourses: Set<Course>
    @Binding var response: String
    @Binding var isLoading: Bool
    let apiService: APIService
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @State private var daysAhead = 7
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Courses:")
                        .font(.headline)
                        .foregroundColor(themeManager.textColor)
                    
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
                                        .foregroundColor(themeManager.textColor)
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                    .padding()
                    .background(themeManager.surfaceColor)
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Study Plan Duration:")
                        .font(.headline)
                        .foregroundColor(themeManager.textColor)
                    
                    HStack {
                        Text("\(daysAhead) days")
                            .foregroundColor(themeManager.textColor)
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
                    .background(themeManager.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(selectedCourses.isEmpty || isLoading)
                
                if !response.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("AI Study Plan")
                                .font(.headline)
                                .foregroundColor(themeManager.textColor)
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
                                .background(themeManager.surfaceColor)
                                .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(themeManager.backgroundColor)
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
        .background(themeManager.backgroundColor)
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
