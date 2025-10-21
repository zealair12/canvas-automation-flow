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
            .toolbarVisibility(.visible, for: .tabBar) // Ensure tab bar is visible
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
    @EnvironmentObject var apiService: APIService
    
    // Assignment statistics for this course
    private var courseAssignments: [Assignment] {
        apiService.assignments.filter { $0.courseId == course.canvasCourseId }
    }
    
    private var assignmentStats: (total: Int, overdue: Int, dueSoon: Int) {
        let total = courseAssignments.count
        let overdue = courseAssignments.filter { $0.isOverdue }.count
        let dueSoon = courseAssignments.filter { $0.isDueSoon && !$0.isOverdue }.count
        return (total, overdue, dueSoon)
    }
    
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
            
            // Assignment Statistics Row
            if assignmentStats.total > 0 {
                HStack(spacing: 12) {
                    // Total Assignments
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 11))
                        Text("\(assignmentStats.total)")
                            .font(.caption)
                    }
                    .foregroundColor(themeManager.secondaryTextColor)
                    
                    // Overdue Assignments
                    if assignmentStats.overdue > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 11))
                            Text("\(assignmentStats.overdue) overdue")
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.2))
                        )
                    }
                    
                    // Due Soon Assignments
                    if assignmentStats.dueSoon > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 11))
                            Text("\(assignmentStats.dueSoon) due soon")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.2))
                        )
                    }
                    
                    Spacer()
                }
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
    @State private var showingCourseSelection = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Selected Courses:")
                            .font(.headline)
                            .foregroundColor(themeManager.textColor)
                        
                        Spacer()
                        
                        Button(action: {
                            showingCourseSelection = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Course")
                            }
                            .font(.subheadline)
                            .foregroundColor(themeManager.accentColor)
                        }
                    }
                    
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
                            
                            if selectedCourses.isEmpty {
                                Text("No courses selected")
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.secondaryTextColor)
                                    .italic()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
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
                            HStack(spacing: 12) {
                                Button("Export Calendar") {
                                    exportToCalendar()
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                                
                                Button("Copy") {
                                    UIPasteboard.general.string = response
                                }
                                .font(.caption)
                                .foregroundColor(.green)
                            }
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
        .sheet(isPresented: $showingCourseSelection) {
            CourseSelectionSheet(
                selectedCourses: $selectedCourses,
                availableCourses: apiService.courses
            )
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
    
    private func exportToCalendar() {
        // Generate .ics file content
        let icsContent = generateICSContent()
        
        // Create a temporary file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "StudyPlan_\(Date().timeIntervalSince1970).ics"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try icsContent.write(to: fileURL, atomically: true, encoding: .utf8)
            
            // Present share sheet
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(activityVC, animated: true)
            }
        } catch {
            print("Error creating calendar file: \(error)")
        }
    }
    
    private func generateICSContent() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        var icsContent = """
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Canvas Automation Flow//Study Plan//EN
CALSCALE:GREGORIAN
METHOD:PUBLISH
"""
        
        // Add study plan events based on assignments
        for course in selectedCourses {
            // Get assignments for this course (this would be enhanced with real API data)
            let assignments = getAssignmentsForCourse(course)
            
            for assignment in assignments {
                if let dueDateString = assignment.dueAt,
                   let dueDate = parseDate(from: dueDateString) {
                    let startDate = Calendar.current.date(byAdding: .day, value: -1, to: dueDate) ?? dueDate
                    
                    icsContent += """
BEGIN:VEVENT
UID:\(UUID().uuidString)@canvasautomation.com
DTSTART:\(formatter.string(from: startDate))
DTEND:\(formatter.string(from: dueDate))
SUMMARY:Study for \(assignment.name)
DESCRIPTION:Assignment: \(assignment.name)\\nCourse: \(course.name)\\nDue: \(dueDate.formatted())
LOCATION:\(course.name)
STATUS:CONFIRMED
TRANSP:OPAQUE
END:VEVENT
"""
                }
            }
        }
        
        icsContent += """
END:VCALENDAR
"""
        
        return icsContent
    }
    
    private func getAssignmentsForCourse(_ course: Course) -> [Assignment] {
        // This would be enhanced to fetch real assignment data from the API
        // For now, return sample data
        return apiService.assignments.filter { $0.courseId == course.canvasCourseId }
    }
    
    private func parseDate(from dateString: String) -> Date? {
        let formatters = [
            // ISO 8601 format (most common from Canvas API)
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            // Alternative formats
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
}

struct CourseSelectionSheet: View {
    @Binding var selectedCourses: Set<Course>
    let availableCourses: [Course]
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Select Courses for Study Plan")
                    .font(.headline)
                    .foregroundColor(themeManager.textColor)
                    .padding(.horizontal)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(availableCourses) { course in
                            CourseSelectionRow(
                                course: course,
                                isSelected: selectedCourses.contains(course),
                                onToggle: { isSelected in
                                    if isSelected {
                                        selectedCourses.insert(course)
                                    } else {
                                        selectedCourses.remove(course)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("Select Courses")
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

struct CourseSelectionRow: View {
    let course: Course
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Button(action: {
                onToggle(!isSelected)
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? themeManager.accentColor : themeManager.secondaryTextColor)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.subheadline)
                    .foregroundColor(themeManager.textColor)
                    .lineLimit(2)
                
                Text(course.courseCode)
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            
            Spacer()
        }
        .padding()
        .background(themeManager.surfaceColor)
        .cornerRadius(8)
    }
}


#Preview {
    CoursesView()
        .environmentObject(APIService())
}
