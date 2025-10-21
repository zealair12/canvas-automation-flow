//
//  CourseDetailView.swift
//  CanvasAutomationFlow
//
//  Course Detail View - Replaces dock navigation with course tabs
//  No API calls - shows structured content
//

import SwiftUI

// MARK: - Data Models
struct CourseContent {
    let overview: String?
    let quickLinks: [QuickLink]
    let announcements: [CourseAnnouncement]
}

struct QuickLink {
    let icon: String
    let title: String
    let color: Color
}

struct CourseAnnouncement {
    let id: String
    let title: String
    let content: String
    let postedAt: Date
}

struct CourseDetailView: View {
    let course: Course
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 0
    
    var body: some View {
        HStack(spacing: 0) {
            // Left vertical dock
            VStack(spacing: 0) {
                CourseTabButton(title: "Home", icon: "house.fill", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                CourseTabButton(title: "Syllabus", icon: "doc.text.fill", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                CourseTabButton(title: "Announcements", icon: "megaphone.fill", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
                CourseTabButton(title: "Modules", icon: "square.stack.3d.up.fill", isSelected: selectedTab == 3) {
                    selectedTab = 3
                }
                CourseTabButton(title: "Assignments", icon: "doc.text.fill", isSelected: selectedTab == 4) {
                    selectedTab = 4
                }
                CourseTabButton(title: "Discussions", icon: "bubble.left.and.bubble.right.fill", isSelected: selectedTab == 5) {
                    selectedTab = 5
                }
            }
            .frame(width: 80)
            .background(themeManager.surfaceColor)
            
            // Content area
            Group {
                switch selectedTab {
                case 0:
                    CourseHomeView(course: course)
                case 1:
                    CourseSyllabusView(course: course)
                case 2:
                    CourseAnnouncementsView(course: course)
                case 3:
                    CourseModulesView(course: course)
                case 4:
                    CourseAssignmentsView(course: course)
                case 5:
                    CourseDiscussionsView(course: course)
                default:
                    CourseHomeView(course: course)
                }
            }
        }
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(themeManager.backgroundColor)
        .toolbar(.hidden, for: .tabBar) // Hide the main dock
    }
}

// MARK: - Course Tab Button
struct CourseTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 10))
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80, height: 60)
            .foregroundColor(isSelected ? themeManager.accentColor : themeManager.secondaryTextColor)
            .background(isSelected ? themeManager.accentColor.opacity(0.1) : Color.clear)
        }
    }
}

// MARK: - Course Home View
struct CourseHomeView: View {
    let course: Course
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var apiService: APIService
    @State private var courseContent: CourseContent?
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Course Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(course.name)
                        .futuristicFont(.futuristicTitle)
                        .foregroundColor(themeManager.textColor)
                    
                    Text(course.courseCode)
                        .futuristicFont(.futuristicHeadline)
                        .foregroundColor(themeManager.accentColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .futuristicCard()
                .padding(.horizontal, 20)
                
                if isLoading {
                    ProgressView("Loading course content...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let content = courseContent {
                    // Dynamic Course Overview
                    if let overview = content.overview, !overview.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Course Overview")
                                .futuristicFont(.futuristicHeadline)
                                .foregroundColor(themeManager.accentColor)
                            
                            Text(overview)
                                .futuristicFont(.futuristicBody)
                                .foregroundColor(themeManager.textColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .futuristicCard()
                        .padding(.horizontal, 20)
                    }
                    
                    // Dynamic Quick Links
                    if !content.quickLinks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Links")
                                .futuristicFont(.futuristicHeadline)
                                .foregroundColor(themeManager.accentColor)
                            
                            ForEach(content.quickLinks, id: \.title) { link in
                                QuickLinkRow(icon: link.icon, title: link.title, color: link.color)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .futuristicCard()
                        .padding(.horizontal, 20)
                    }
                    
                    // Dynamic Announcements
                    if !content.announcements.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Announcements")
                                .futuristicFont(.futuristicHeadline)
                                .foregroundColor(themeManager.accentColor)
                            
                            ForEach(content.announcements.prefix(3), id: \.id) { announcement in
                                AnnouncementRow(announcement: announcement)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .futuristicCard()
                        .padding(.horizontal, 20)
                    }
                } else {
                    // Fallback content when no dynamic content is available
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Course Overview")
                            .futuristicFont(.futuristicHeadline)
                            .foregroundColor(themeManager.accentColor)
                        
                        Text("Welcome to \(course.name). This course page provides access to all course materials, assignments, and resources.")
                            .futuristicFont(.futuristicBody)
                            .foregroundColor(themeManager.textColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .futuristicCard()
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical)
        }
        .background(themeManager.backgroundColor)
        .onAppear {
            loadCourseContent()
        }
    }
    
    private func loadCourseContent() {
        // Simulate API call to get course content
        // In a real implementation, this would call the Canvas API
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            courseContent = CourseContent(
                overview: "This course covers fundamental concepts and provides comprehensive learning materials.",
                quickLinks: [
                    QuickLink(icon: "doc.text.fill", title: "View Syllabus", color: .blue),
                    QuickLink(icon: "doc.text.fill", title: "See Assignments", color: .green)
                ],
                announcements: []
            )
            isLoading = false
        }
    }
}

struct QuickLinkRow: View {
    let icon: String
    let title: String
    let color: Color
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .futuristicFont(.futuristicBody)
                .foregroundColor(themeManager.textColor)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(themeManager.secondaryTextColor)
                .font(.system(size: 12))
        }
        .padding(.vertical, 8)
    }
}

struct AnnouncementRow: View {
    let announcement: CourseAnnouncement
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(announcement.title)
                .futuristicFont(.futuristicHeadline)
                .foregroundColor(themeManager.textColor)
            
            Text(announcement.content)
                .futuristicFont(.futuristicBody)
                .foregroundColor(themeManager.secondaryTextColor)
                .lineLimit(3)
            
            Text(formatDate(announcement.postedAt))
                .futuristicFont(.futuristicCaption)
                .foregroundColor(themeManager.accentColor)
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Course Syllabus View
struct CourseSyllabusView: View {
    let course: Course
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Syllabus Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("Course Syllabus")
                        .futuristicFont(.futuristicTitle)
                        .foregroundColor(themeManager.accentColor)
                    
                    Text(course.name)
                        .futuristicFont(.futuristicHeadline)
                        .foregroundColor(themeManager.textColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .futuristicCard()
                .padding(.horizontal, 20)
                
                // Course Description
                VStack(alignment: .leading, spacing: 12) {
                    Text("Course Description")
                        .futuristicFont(.futuristicHeadline)
                        .foregroundColor(themeManager.accentColor)
                    
                    Text("Course syllabus and schedule will appear here. This includes course objectives, grading policy, required materials, and weekly topics.")
                        .futuristicFont(.futuristicBody)
                        .foregroundColor(themeManager.textColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .futuristicCard()
                .padding(.horizontal, 20)
                
                // Grading Policy
                VStack(alignment: .leading, spacing: 12) {
                    Text("Grading Policy")
                        .futuristicFont(.futuristicHeadline)
                        .foregroundColor(themeManager.accentColor)
                    
                    SyllabusItemRow(title: "Assignments", percentage: "40%")
                    SyllabusItemRow(title: "Quizzes", percentage: "20%")
                    SyllabusItemRow(title: "Midterm Exam", percentage: "20%")
                    SyllabusItemRow(title: "Final Exam", percentage: "20%")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .futuristicCard()
                .padding(.horizontal, 20)
            }
            .padding(.vertical)
        }
        .background(themeManager.backgroundColor)
    }
}

struct SyllabusItemRow: View {
    let title: String
    let percentage: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Text(title)
                .futuristicFont(.futuristicBody)
                .foregroundColor(themeManager.textColor)
            
            Spacer()
            
            Text(percentage)
                .futuristicFont(.futuristicBody)
                .foregroundColor(themeManager.accentColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Course Announcements View
struct CourseAnnouncementsView: View {
    let course: Course
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                EmptyStateView(
                    icon: "megaphone",
                    title: "No Announcements",
                    message: "Course announcements will appear here when your instructor posts them."
                )
            }
            .padding()
        }
        .background(themeManager.backgroundColor)
    }
}

// MARK: - Course Modules View
struct CourseModulesView: View {
    let course: Course
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                EmptyStateView(
                    icon: "square.stack.3d.up",
                    title: "No Modules",
                    message: "Course modules and learning materials will appear here."
                )
            }
            .padding()
        }
        .background(themeManager.backgroundColor)
    }
}

// MARK: - Course Assignments View
struct CourseAssignmentsView: View {
    let course: Course
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    
    var courseAssignments: [Assignment] {
        apiService.assignments.filter { $0.courseId == course.canvasCourseId }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if courseAssignments.isEmpty {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "No Assignments",
                        message: "This course doesn't have any assignments yet."
                    )
                } else {
                    ForEach(courseAssignments) { assignment in
                        NavigationLink(destination: AssignmentDetailView(assignment: assignment)) {
                            AssignmentDetailRowView(assignment: assignment)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding()
        }
        .background(themeManager.backgroundColor)
    }
}

// MARK: - Course Discussions View
struct CourseDiscussionsView: View {
    let course: Course
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                EmptyStateView(
                    icon: "bubble.left.and.bubble.right",
                    title: "No Discussions",
                    message: "Discussion topics and forums will appear here."
                )
            }
            .padding()
        }
        .background(themeManager.backgroundColor)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(themeManager.secondaryTextColor)
            
            Text(title)
                .futuristicFont(.futuristicTitle)
                .foregroundColor(themeManager.textColor)
            
            Text(message)
                .futuristicFont(.futuristicBody)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

