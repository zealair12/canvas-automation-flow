//
//  CourseDetailView.swift
//  CanvasAutomationFlow
//
//  Course Detail View - Replaces dock navigation with course tabs
//  No API calls - shows structured content
//

import SwiftUI
import WebKit

struct CourseDetailView: View {
    let course: Course
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
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
                case 6:
                    CourseGradesView(course: course)
                default:
                    CourseHomeView(course: course)
                }
            }
            
            // Custom bottom navigation - replaces main dock
            HStack(spacing: 0) {
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
                CourseTabButton(title: "Grades", icon: "chart.bar.fill", isSelected: selectedTab == 6) {
                    selectedTab = 6
                }
            }
            .frame(height: 50)
            .background(themeManager.surfaceColor)
        }
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(themeManager.backgroundColor)
        .toolbarVisibility(.hidden, for: .tabBar) // Hide the main dock when in course view
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
            Image(systemName: icon)
                .font(.system(size: 20))
                .frame(maxWidth: .infinity)
                .foregroundColor(isSelected ? themeManager.accentColor : themeManager.secondaryTextColor)
        }
    }
}

// MARK: - Course Home View
struct CourseHomeView: View {
    let course: Course
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var frontPage: CoursePage?
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
                
                // Front Page Content from Canvas
                if isLoading {
                    ProgressView("Loading course home page...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let page = frontPage, let body = page.body {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(page.title)
                            .futuristicFont(.futuristicHeadline)
                            .foregroundColor(themeManager.accentColor)
                        
                        // Display Canvas HTML content
                        HTMLContentView(htmlContent: body)
                            .frame(minHeight: 300)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .futuristicCard()
                    .padding(.horizontal, 20)
                } else {
                    // Fallback if no front page
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Course Overview")
                            .futuristicFont(.futuristicHeadline)
                            .foregroundColor(themeManager.accentColor)
                        
                        Text("Welcome to \(course.name). Use the tabs below to access course materials, assignments, and resources.")
                            .futuristicFont(.futuristicBody)
                            .foregroundColor(themeManager.textColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .futuristicCard()
                    .padding(.horizontal, 20)
                }
                
                // Quick Links
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Links")
                        .futuristicFont(.futuristicHeadline)
                        .foregroundColor(themeManager.accentColor)
                    
                    QuickLinkRow(icon: "doc.text.fill", title: "View Syllabus", color: .blue)
                    QuickLinkRow(icon: "square.stack.3d.up.fill", title: "Browse Modules", color: .purple)
                    QuickLinkRow(icon: "doc.text.fill", title: "See Assignments", color: .green)
                    QuickLinkRow(icon: "chart.bar.fill", title: "Check Grades", color: .orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .futuristicCard()
                .padding(.horizontal, 20)
            }
            .padding(.vertical)
        }
        .background(themeManager.backgroundColor)
        .task {
            await loadFrontPage()
        }
    }
    
    private func loadFrontPage() async {
        isLoading = true
        frontPage = await apiService.getCourseFrontPage(courseId: course.canvasCourseId)
        isLoading = false
    }
}

// MARK: - HTML Content View
struct HTMLContentView: View {
    let htmlContent: String
    @State private var webViewHeight: CGFloat = 300
    
    var body: some View {
        HTMLWebView(htmlContent: htmlContent, height: $webViewHeight)
            .frame(height: webViewHeight)
            .cornerRadius(8)
    }
}

struct HTMLWebView: UIViewRepresentable {
    let htmlContent: String
    @Binding var height: CGFloat
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let htmlString = """
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    font-size: 16px;
                    line-height: 1.6;
                    color: #F2F2F2;
                    background-color: transparent;
                    margin: 16px;
                    padding: 0;
                }
                a { color: #BB86FC; text-decoration: none; }
                img { max-width: 100%; height: auto; }
                pre, code {
                    background-color: #1F1F1F;
                    padding: 8px;
                    border-radius: 4px;
                    font-family: 'SF Mono', Monaco, monospace;
                }
                blockquote {
                    border-left: 3px solid #BB86FC;
                    margin-left: 0;
                    padding-left: 16px;
                    opacity: 0.8;
                }
                h1, h2, h3 { color: #BB86FC; }
                ul, ol { padding-left: 20px; }
            </style>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
        
        webView.loadHTMLString(htmlString, baseURL: nil)
        
        // Calculate height
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            webView.evaluateJavaScript("document.body.scrollHeight") { result, error in
                if let height = result as? CGFloat {
                    self.height = max(height + 40, 300)
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
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

// MARK: - Course Grades View
struct CourseGradesView: View {
    let course: Course
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Overall Grade Card
                VStack(spacing: 12) {
                    Text("Current Grade")
                        .futuristicFont(.futuristicHeadline)
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    Text("--")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(themeManager.accentColor)
                    
                    Text("Grade not yet available")
                        .futuristicFont(.futuristicCaption)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .futuristicCard()
                .padding(.horizontal, 20)
                
                // Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("About Grades")
                        .futuristicFont(.futuristicHeadline)
                        .foregroundColor(themeManager.accentColor)
                    
                    Text("Your current grade and individual assignment scores will appear here once grading begins.")
                        .futuristicFont(.futuristicBody)
                        .foregroundColor(themeManager.textColor)
                        .fixedSize(horizontal: false, vertical: true)
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

