//
//  CourseDetailView.swift
//  CanvasAutomationFlow
//
//  Course Detail View with all available Canvas features
//

import SwiftUI
import WebKit

struct CourseDetailView: View {
    let course: Course
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CourseHomeView(courseId: course.canvasCourseId)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            CourseSyllabusView(courseId: course.canvasCourseId)
                .tabItem {
                    Label("Syllabus", systemImage: "doc.text.fill")
                }
                .tag(1)
            
            CourseAnnouncementsView(courseId: course.canvasCourseId)
                .tabItem {
                    Label("Announcements", systemImage: "megaphone.fill")
                }
                .tag(2)
            
            CourseModulesView(courseId: course.canvasCourseId)
                .tabItem {
                    Label("Modules", systemImage: "square.stack.3d.up.fill")
                }
                .tag(3)
            
            CourseAssignmentsView(courseId: course.canvasCourseId)
                .tabItem {
                    Label("Assignments", systemImage: "doc.text.fill")
                }
                .tag(4)
            
            CourseDiscussionsView(courseId: course.canvasCourseId)
                .tabItem {
                    Label("Discussions", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(5)
            
            CourseGradesView(courseId: course.canvasCourseId)
                .tabItem {
                    Label("Grades", systemImage: "chart.bar.fill")
                }
                .tag(6)
        }
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(themeManager.backgroundColor)
    }
}

// MARK: - Course Home View
struct CourseHomeView: View {
    let courseId: String
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var frontPage: CoursePage?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView("Loading home page...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let error = errorMessage {
                    ErrorView(message: error)
                } else if let page = frontPage {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(page.title)
                            .futuristicFont(.futuristicTitle)
                            .foregroundColor(themeManager.textColor)
                        
                        if let body = page.body {
                            HTMLContentView(htmlContent: body)
                                .frame(minHeight: 400)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .futuristicCard()
                    .padding(.horizontal, 20)
                } else {
                    Text("No home page content available")
                        .foregroundColor(themeManager.secondaryTextColor)
                        .padding()
                }
            }
        }
        .background(themeManager.backgroundColor)
        .task {
            await loadFrontPage()
        }
    }
    
    private func loadFrontPage() async {
        isLoading = true
        errorMessage = nil
        
        let result = await apiService.getCourseFrontPage(courseId: courseId)
        if let page = result {
            frontPage = page
        } else {
            errorMessage = "Failed to load home page"
        }
        
        isLoading = false
    }
}

// MARK: - Course Syllabus View
struct CourseSyllabusView: View {
    let courseId: String
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var syllabusBody: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView("Loading syllabus...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let error = errorMessage {
                    ErrorView(message: error)
                } else if let syllabus = syllabusBody, !syllabus.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Course Syllabus")
                            .futuristicFont(.futuristicTitle)
                            .foregroundColor(themeManager.accentColor)
                        
                        HTMLContentView(htmlContent: syllabus)
                            .frame(minHeight: 400)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .futuristicCard()
                    .padding(.horizontal, 20)
                } else {
                    Text("No syllabus available for this course")
                        .foregroundColor(themeManager.secondaryTextColor)
                        .padding()
                }
            }
        }
        .background(themeManager.backgroundColor)
        .task {
            await loadSyllabus()
        }
    }
    
    private func loadSyllabus() async {
        isLoading = true
        errorMessage = nil
        
        let syllabus = await apiService.getCourseSyllabus(courseId: courseId)
        if let syllabus = syllabus {
            syllabusBody = syllabus
        } else {
            errorMessage = "Failed to load syllabus"
        }
        
        isLoading = false
    }
}

// MARK: - Course Announcements View
struct CourseAnnouncementsView: View {
    let courseId: String
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var announcements: [Announcement] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedAnnouncement: Announcement?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading announcements...")
                } else if let error = errorMessage {
                    ErrorView(message: error)
                } else if announcements.isEmpty {
                    EmptyStateView(
                        icon: "megaphone",
                        title: "No Announcements",
                        message: "There are no announcements for this course yet."
                    )
                } else {
                    List(announcements) { announcement in
                        Button(action: {
                            selectedAnnouncement = announcement
                        }) {
                            AnnouncementRowView(announcement: announcement)
                        }
                    }
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("Announcements")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadAnnouncements()
            }
            .sheet(item: $selectedAnnouncement) { announcement in
                AnnouncementDetailView(announcement: announcement)
            }
        }
    }
    
    private func loadAnnouncements() async {
        isLoading = true
        errorMessage = nil
        
        let result = await apiService.getCourseAnnouncements(courseId: courseId)
        if let announcements = result {
            self.announcements = announcements
        } else {
            errorMessage = "Failed to load announcements"
        }
        
        isLoading = false
    }
}

// MARK: - Course Modules View
struct CourseModulesView: View {
    let courseId: String
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var modules: [CourseModule] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var expandedModules: Set<String> = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if isLoading {
                    ProgressView("Loading modules...")
                        .padding()
                } else if let error = errorMessage {
                    ErrorView(message: error)
                } else if modules.isEmpty {
                    EmptyStateView(
                        icon: "square.stack.3d.up",
                        title: "No Modules",
                        message: "This course doesn't have any modules yet."
                    )
                } else {
                    ForEach(modules) { module in
                        ModuleRowView(
                            module: module,
                            isExpanded: expandedModules.contains(module.id),
                            onToggle: {
                                if expandedModules.contains(module.id) {
                                    expandedModules.remove(module.id)
                                } else {
                                    expandedModules.insert(module.id)
                                }
                            }
                        )
                    }
                }
            }
            .padding()
        }
        .background(themeManager.backgroundColor)
        .task {
            await loadModules()
        }
    }
    
    private func loadModules() async {
        isLoading = true
        errorMessage = nil
        
        let result = await apiService.getCourseModules(courseId: courseId)
        if let modules = result {
            self.modules = modules
        } else {
            errorMessage = "Failed to load modules"
        }
        
        isLoading = false
    }
}

// MARK: - Course Assignments View
struct CourseAssignmentsView: View {
    let courseId: String
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    
    var courseAssignments: [Assignment] {
        apiService.assignments.filter { $0.courseId == courseId }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if courseAssignments.isEmpty {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "No Assignments",
                        message: "This course doesn't have any assignments yet."
                    )
                } else {
                    List(courseAssignments) { assignment in
                        NavigationLink(destination: AssignmentDetailView(assignment: assignment)) {
                            AssignmentDetailRowView(assignment: assignment)
                        }
                    }
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("Assignments")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Course Discussions View
struct CourseDiscussionsView: View {
    let courseId: String
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var discussions: [Discussion] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedDiscussion: Discussion?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading discussions...")
                } else if let error = errorMessage {
                    ErrorView(message: error)
                } else if discussions.isEmpty {
                    EmptyStateView(
                        icon: "bubble.left.and.bubble.right",
                        title: "No Discussions",
                        message: "There are no discussion topics for this course yet."
                    )
                } else {
                    List(discussions) { discussion in
                        Button(action: {
                            selectedDiscussion = discussion
                        }) {
                            DiscussionRowView(discussion: discussion)
                        }
                    }
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("Discussions")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadDiscussions()
            }
            .sheet(item: $selectedDiscussion) { discussion in
                DiscussionDetailView(discussion: discussion)
            }
        }
    }
    
    private func loadDiscussions() async {
        isLoading = true
        errorMessage = nil
        
        let result = await apiService.getCourseDiscussions(courseId: courseId)
        if let discussions = result {
            self.discussions = discussions
        } else {
            errorMessage = "Failed to load discussions"
        }
        
        isLoading = false
    }
}

// MARK: - Course Grades View
struct CourseGradesView: View {
    let courseId: String
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var gradeInfo: CourseGrade?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView("Loading grades...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let error = errorMessage {
                    ErrorView(message: error)
                } else if let grade = gradeInfo {
                    VStack(spacing: 20) {
                        // Overall Grade Card
                        VStack(spacing: 12) {
                            Text("Current Grade")
                                .futuristicFont(.futuristicHeadline)
                                .foregroundColor(themeManager.secondaryTextColor)
                            
                            Text(grade.currentGrade ?? "N/A")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(themeManager.accentColor)
                            
                            if let score = grade.currentScore {
                                Text("\(String(format: "%.2f", score))%")
                                    .futuristicFont(.futuristicTitle)
                                    .foregroundColor(themeManager.textColor)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .futuristicCard()
                        .padding(.horizontal, 20)
                        
                        // Assignment Grades
                        if !grade.assignmentGrades.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Assignment Grades")
                                    .futuristicFont(.futuristicHeadline)
                                    .foregroundColor(themeManager.accentColor)
                                    .padding(.horizontal)
                                
                                ForEach(grade.assignmentGrades, id: \.assignmentId) { assignmentGrade in
                                    AssignmentGradeRowView(assignmentGrade: assignmentGrade)
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                    }
                } else {
                    Text("No grade information available")
                        .foregroundColor(themeManager.secondaryTextColor)
                        .padding()
                }
            }
        }
        .background(themeManager.backgroundColor)
        .task {
            await loadGrades()
        }
    }
    
    private func loadGrades() async {
        isLoading = true
        errorMessage = nil
        
        let result = await apiService.getCourseGrades(courseId: courseId)
        if let grades = result {
            gradeInfo = grades
        } else {
            errorMessage = "Failed to load grades"
        }
        
        isLoading = false
    }
}

// MARK: - Supporting Views

struct HTMLContentView: View {
    let htmlContent: String
    @EnvironmentObject var themeManager: ThemeManager
    @State private var webViewHeight: CGFloat = 400
    
    var body: some View {
        HTMLWebView(htmlContent: htmlContent, height: $webViewHeight)
            .frame(height: webViewHeight)
            .background(themeManager.surfaceColor)
            .cornerRadius(8)
    }
}

struct HTMLWebView: UIViewRepresentable {
    let htmlContent: String
    @Binding var height: CGFloat
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
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
                a { color: #BB86FC; }
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
                    self.height = height + 40
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

struct ErrorView: View {
    let message: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

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

// MARK: - Row Views

struct AnnouncementRowView: View {
    let announcement: Announcement
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(announcement.title)
                .futuristicFont(.futuristicHeadline)
                .foregroundColor(themeManager.textColor)
            
            if let postedAt = announcement.postedAt {
                Text(formatDate(postedAt))
                    .futuristicFont(.futuristicCaption)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            
            if let author = announcement.author {
                Text("by \(author)")
                    .futuristicFont(.futuristicCaption)
                    .foregroundColor(themeManager.accentColor)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        
        return dateString
    }
}

struct ModuleRowView: View {
    let module: CourseModule
    let isExpanded: Bool
    let onToggle: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(themeManager.accentColor)
                    
                    Text(module.name)
                        .futuristicFont(.futuristicHeadline)
                        .foregroundColor(themeManager.textColor)
                    
                    Spacer()
                    
                    if let itemCount = module.itemsCount {
                        Text("\(itemCount) items")
                            .futuristicFont(.futuristicCaption)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                }
            }
            
            if isExpanded && !module.items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(module.items) { item in
                        ModuleItemRow(item: item)
                    }
                }
                .padding(.leading, 24)
            }
        }
        .padding()
        .futuristicCard()
    }
}

struct ModuleItemRow: View {
    let item: ModuleItem
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Image(systemName: iconForItemType(item.type))
                .foregroundColor(themeManager.accentColor)
            
            Text(item.title)
                .futuristicFont(.futuristicBody)
                .foregroundColor(themeManager.textColor)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func iconForItemType(_ type: String) -> String {
        switch type.lowercased() {
        case "assignment": return "doc.text"
        case "quiz": return "questionmark.circle"
        case "file": return "doc"
        case "page": return "doc.plaintext"
        case "discussion": return "bubble.left.and.bubble.right"
        case "externalurl": return "link"
        case "externaltool": return "wrench"
        default: return "circle"
        }
    }
}

struct DiscussionRowView: View {
    let discussion: Discussion
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(discussion.title)
                .futuristicFont(.futuristicHeadline)
                .foregroundColor(themeManager.textColor)
            
            HStack {
                if let postedAt = discussion.postedAt {
                    Text(formatDate(postedAt))
                        .futuristicFont(.futuristicCaption)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                if let unreadCount = discussion.unreadCount, unreadCount > 0 {
                    Text("\(unreadCount) unread")
                        .futuristicFont(.futuristicCaption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        
        return dateString
    }
}

struct AssignmentGradeRowView: View {
    let assignmentGrade: AssignmentGrade
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(assignmentGrade.assignmentName)
                    .futuristicFont(.futuristicBody)
                    .foregroundColor(themeManager.textColor)
                
                if let submittedAt = assignmentGrade.submittedAt {
                    Text("Submitted: \(formatDate(submittedAt))")
                        .futuristicFont(.futuristicCaption)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
            
            Spacer()
            
            if let score = assignmentGrade.score, let possiblePoints = assignmentGrade.possiblePoints {
                Text("\(String(format: "%.1f", score))/\(String(format: "%.0f", possiblePoints))")
                    .futuristicFont(.futuristicHeadline)
                    .foregroundColor(themeManager.accentColor)
            } else {
                Text("Not graded")
                    .futuristicFont(.futuristicCaption)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
        }
        .padding()
        .futuristicCard()
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
        
        return dateString
    }
}

// MARK: - Detail Views

struct AnnouncementDetailView: View {
    let announcement: Announcement
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(announcement.title)
                        .futuristicFont(.futuristicTitle)
                        .foregroundColor(themeManager.textColor)
                    
                    if let author = announcement.author, let postedAt = announcement.postedAt {
                        HStack {
                            Text("by \(author)")
                                .futuristicFont(.futuristicCaption)
                                .foregroundColor(themeManager.accentColor)
                            
                            Text("•")
                                .foregroundColor(themeManager.secondaryTextColor)
                            
                            Text(formatDate(postedAt))
                                .futuristicFont(.futuristicCaption)
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                    }
                    
                    if let message = announcement.message {
                        HTMLContentView(htmlContent: message)
                            .frame(minHeight: 300)
                    }
                }
                .padding()
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("Announcement")
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
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        
        return dateString
    }
}

struct DiscussionDetailView: View {
    let discussion: Discussion
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(discussion.title)
                        .futuristicFont(.futuristicTitle)
                        .foregroundColor(themeManager.textColor)
                    
                    if let postedAt = discussion.postedAt {
                        Text(formatDate(postedAt))
                            .futuristicFont(.futuristicCaption)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                    
                    if let message = discussion.message {
                        HTMLContentView(htmlContent: message)
                            .frame(minHeight: 300)
                    }
                    
                    // TODO: Add discussion entries (replies)
                    Text("Discussion replies coming soon...")
                        .futuristicFont(.futuristicBody)
                        .foregroundColor(themeManager.secondaryTextColor)
                        .padding()
                }
                .padding()
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("Discussion")
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
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        
        return dateString
    }
}

