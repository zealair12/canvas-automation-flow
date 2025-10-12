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
    @State private var showVerticalDock = true
    
    var courseAssignmentCount: Int {
        apiService.assignments.filter { $0.courseId == course.canvasCourseId }.count
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // VERTICAL DOCK (Left Side)
                if showVerticalDock {
                    VStack(spacing: 16) {
                        // Toggle button to collapse/expand
                        Button(action: { 
                            withAnimation(.easeInOut(duration: 0.3)) { 
                                showVerticalDock.toggle() 
                            }
                        }) {
                            Image(systemName: "sidebar.left")
                                .font(.system(size: 20))
                                .foregroundColor(themeManager.accentColor)
                        }
                        .padding(.top, 20)
                        
                        Divider()
                            .background(themeManager.secondaryTextColor.opacity(0.3))
                        
                        // Course Navigation Buttons
                        VerticalTabButton(icon: "house.fill", 
                                        label: "Home", 
                                        isSelected: selectedTab == 0) {
                            selectedTab = 0
                        }
                        
                        VerticalTabButton(icon: "doc.text.fill", 
                                        label: "Syllabus", 
                                        isSelected: selectedTab == 1) {
                            selectedTab = 1
                        }
                        
                        VerticalTabButton(icon: "megaphone.fill", 
                                        label: "Announce", 
                                        isSelected: selectedTab == 2) {
                            selectedTab = 2
                        }
                        
                        VerticalTabButton(icon: "square.stack.3d.up.fill", 
                                        label: "Modules", 
                                        isSelected: selectedTab == 3) {
                            selectedTab = 3
                        }
                        
                        // HIGHLIGHTED - Assignments with badge
                        VerticalTabButton(icon: "doc.on.doc.fill", 
                                        label: "Assign", 
                                        isSelected: selectedTab == 4,
                                        badge: courseAssignmentCount > 0 ? courseAssignmentCount : nil) {
                            selectedTab = 4
                        }
                        
                        VerticalTabButton(icon: "bubble.left.and.bubble.right.fill", 
                                        label: "Discuss", 
                                        isSelected: selectedTab == 5) {
                            selectedTab = 5
                        }
                        
                        VerticalTabButton(icon: "chart.bar.fill", 
                                        label: "Grades", 
                                        isSelected: selectedTab == 6) {
                            selectedTab = 6
                        }
                        
                        Spacer()
                    }
                    .frame(width: 80)
                    .background(themeManager.surfaceColor)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 2, y: 0)
                    .transition(.move(edge: .leading))
                }
                
                // Collapse button when dock is hidden
                if !showVerticalDock {
                    VStack {
                        Button(action: { 
                            withAnimation(.easeInOut(duration: 0.3)) { 
                                showVerticalDock.toggle() 
                            }
                        }) {
                            Image(systemName: "sidebar.right")
                                .font(.system(size: 20))
                                .foregroundColor(themeManager.accentColor)
                                .padding(12)
                                .background(themeManager.surfaceColor)
                                .cornerRadius(8)
                                .shadow(color: Color.black.opacity(0.1), radius: 3)
                        }
                        .padding(.top, 20)
                        .padding(.leading, 8)
                        
                        Spacer()
                    }
                    .transition(.move(edge: .leading))
                }
                
                // CONTENT AREA (Right Side)
                VStack(spacing: 0) {
                    // Content based on selected tab
                    Group {
                        switch selectedTab {
                        case 0: CourseHomeView(course: course, onTabChange: { selectedTab = $0 })
                        case 1: CourseSyllabusView(course: course)
                        case 2: CourseAnnouncementsView(course: course)
                        case 3: CourseModulesView(course: course)
                        case 4: EnhancedCourseAssignmentsView(course: course)
                        case 5: CourseDiscussionsView(course: course)
                        case 6: CourseGradesView(course: course)
                        default: CourseHomeView(course: course, onTabChange: { selectedTab = $0 })
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(themeManager.backgroundColor)
        .toolbarVisibility(.hidden, for: .tabBar) // Hide the main dock when in course view
    }
}

// MARK: - Vertical Tab Button
struct VerticalTabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    var badge: Int? = nil
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? themeManager.accentColor : themeManager.secondaryTextColor)
                    
                    if let count = badge, count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .padding(2)
                            .background(Circle().fill(Color.red))
                            .offset(x: 10, y: -6)
                    }
                }
                
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? themeManager.accentColor : themeManager.secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 70)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
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
    var onTabChange: ((Int) -> Void)? = nil
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var frontPage: CoursePage?
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Course Header with Statistics
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(course.name)
                            .futuristicFont(.futuristicTitle)
                            .foregroundColor(themeManager.textColor)
                        
                        Text(course.courseCode)
                            .futuristicFont(.futuristicHeadline)
                            .foregroundColor(themeManager.accentColor)
                    }
                    
                    // Course Statistics
                    HStack(spacing: 20) {
                        CourseStatBadge(
                            icon: "doc.on.doc.fill",
                            count: courseAssignmentCount,
                            label: "Assignments",
                            color: .blue
                        )
                        
                        CourseStatBadge(
                            icon: "exclamationmark.circle.fill",
                            count: overdueCount,
                            label: "Overdue",
                            color: .red
                        )
                        
                        CourseStatBadge(
                            icon: "clock.fill",
                            count: dueSoonCount,
                            label: "Due Soon",
                            color: .orange
                        )
                    }
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
                    
                    Button(action: { onTabChange?(1) }) {
                        QuickLinkRow(icon: "doc.text.fill", title: "View Syllabus", color: .blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { onTabChange?(3) }) {
                        QuickLinkRow(icon: "square.stack.3d.up.fill", title: "Browse Modules", color: .purple)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { onTabChange?(4) }) {
                        QuickLinkRow(icon: "doc.on.doc.fill", title: "See Assignments (\(courseAssignmentCount))", color: .green)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { onTabChange?(6) }) {
                        QuickLinkRow(icon: "chart.bar.fill", title: "Check Grades", color: .orange)
                    }
                    .buttonStyle(PlainButtonStyle())
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
    
    // Computed properties for statistics
    var courseAssignments: [Assignment] {
        apiService.assignments.filter { $0.courseId == course.canvasCourseId }
    }
    
    var courseAssignmentCount: Int {
        courseAssignments.count
    }
    
    var overdueCount: Int {
        courseAssignments.filter { $0.isOverdue }.count
    }
    
    var dueSoonCount: Int {
        courseAssignments.filter { $0.isDueSoon && !$0.isOverdue }.count
    }
    
    private func loadFrontPage() async {
        isLoading = true
        frontPage = await apiService.getCourseFrontPage(courseId: course.canvasCourseId)
        isLoading = false
    }
}

// MARK: - Course Stat Badge
struct CourseStatBadge: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text("\(count)")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(count > 0 ? color : themeManager.secondaryTextColor)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(themeManager.secondaryTextColor)
        }
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

// MARK: - Enhanced Course Assignments View
struct EnhancedCourseAssignmentsView: View {
    let course: Course
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var searchText = ""
    @State private var selectedFilter: AssignmentFilter = .all
    @State private var groupBy: GroupingOption = .status
    
    enum AssignmentFilter: String, CaseIterable {
        case all = "All"
        case dueSoon = "Due Soon"
        case overdue = "Overdue"
        case completed = "Completed"
        case upcoming = "Upcoming"
    }
    
    enum GroupingOption: String, CaseIterable {
        case status = "By Status"
        case dueDate = "By Due Date"
    }
    
    var courseAssignments: [Assignment] {
        let filtered = apiService.assignments.filter { $0.courseId == course.canvasCourseId }
        
        // Apply search filter
        let searched = searchText.isEmpty ? filtered : filtered.filter { assignment in
            assignment.name.localizedCaseInsensitiveContains(searchText) ||
            (assignment.description ?? "").localizedCaseInsensitiveContains(searchText)
        }
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            return searched
        case .dueSoon:
            return searched.filter { $0.isDueSoon && !$0.isOverdue }
        case .overdue:
            return searched.filter { $0.isOverdue }
        case .completed:
            return searched.filter { $0.status == "graded" }
        case .upcoming:
            return searched.filter { !$0.isDueSoon && !$0.isOverdue && $0.status != "graded" }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Course Context Header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Assignments")
                            .font(.title3.bold())
                            .foregroundColor(themeManager.textColor)
                        
                        Text("\(courseAssignments.count) total")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                    
                    Spacer()
                    
                    // Quick Stats
                    HStack(spacing: 12) {
                        StatPill(icon: "exclamationmark.circle.fill", 
                                count: courseAssignments.filter { $0.isOverdue }.count,
                                color: .red)
                        
                        StatPill(icon: "clock.fill", 
                                count: courseAssignments.filter { $0.isDueSoon }.count,
                                color: .orange)
                        
                        StatPill(icon: "checkmark.circle.fill", 
                                count: courseAssignments.filter { $0.status == "graded" }.count,
                                color: .green)
                    }
                }
            }
            .padding()
            .background(themeManager.surfaceColor)
            
            // Search and Filters
            VStack(spacing: 12) {
                SearchBarView(text: $searchText, placeholder: "Search assignments...")
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AssignmentFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter,
                                action: { selectedFilter = filter }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
            
            // Assignments List
            if courseAssignments.isEmpty {
                EmptyStateView(
                    icon: "doc.text",
                    title: searchText.isEmpty ? "No Assignments" : "No Matching Assignments",
                    message: searchText.isEmpty ? 
                        "This course doesn't have any assignments yet." :
                        "Try adjusting your search or filters."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        switch groupBy {
                        case .status:
                            groupedByStatus
                        case .dueDate:
                            groupedByDueDate
                        }
                    }
                    .padding()
                }
            }
        }
        .background(themeManager.backgroundColor)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Section("Group By") {
                        ForEach(GroupingOption.allCases, id: \.self) { option in
                            Button(action: { groupBy = option }) {
                                HStack {
                                    Text(option.rawValue)
                                    if groupBy == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }
    
    // Grouped views
    private var groupedByStatus: some View {
        ForEach(["Overdue", "Due Soon", "Upcoming", "Completed"], id: \.self) { status in
            let filtered = filterByStatus(status)
            if !filtered.isEmpty {
                AssignmentGroupSection(
                    title: status,
                    assignments: filtered,
                    course: course
                )
            }
        }
    }
    
    private var groupedByDueDate: some View {
        ForEach(groupAssignmentsByDate(), id: \.key) { group in
            AssignmentGroupSection(
                title: group.key,
                assignments: group.value,
                course: course
            )
        }
    }
    
    // Helper functions
    private func filterByStatus(_ status: String) -> [Assignment] {
        switch status {
        case "Overdue":
            return courseAssignments.filter { $0.isOverdue }
        case "Due Soon":
            return courseAssignments.filter { $0.isDueSoon && !$0.isOverdue }
        case "Upcoming":
            return courseAssignments.filter { !$0.isDueSoon && !$0.isOverdue && $0.status != "graded" }
        case "Completed":
            return courseAssignments.filter { $0.status == "graded" }
        default:
            return []
        }
    }
    
    private func groupAssignmentsByDate() -> [(key: String, value: [Assignment])] {
        let grouped = Dictionary(grouping: courseAssignments) { assignment -> String in
            guard let dueAt = assignment.dueAt else { return "No Due Date" }
            let formatter = ISO8601DateFormatter()
            guard let date = formatter.date(from: dueAt) else { return "No Due Date" }
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, yyyy"
            return displayFormatter.string(from: date)
        }
        return grouped.sorted { $0.key < $1.key }
    }
}

// MARK: - Supporting Components
struct StatPill: View {
    let icon: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text("\(count)")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(count > 0 ? color : Color.gray)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(count > 0 ? color.opacity(0.2) : Color.gray.opacity(0.1))
        )
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : themeManager.textColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? themeManager.accentColor : themeManager.surfaceColor)
                )
        }
    }
}

struct AssignmentGroupSection: View {
    let title: String
    let assignments: [Assignment]
    let course: Course
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(themeManager.accentColor)
                
                Text("(\(assignments.count))")
                    .font(.subheadline)
                    .foregroundColor(themeManager.secondaryTextColor)
                
                Spacer()
            }
            
            ForEach(assignments) { assignment in
                NavigationLink(destination: AssignmentDetailView(assignment: assignment, course: course)) {
                    EnhancedAssignmentRow(assignment: assignment)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct EnhancedAssignmentRow: View {
    let assignment: Assignment
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Assignment Icon
            Image(systemName: assignmentIcon)
                .font(.system(size: 20))
                .foregroundColor(themeManager.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(assignment.name)
                    .font(.headline)
                    .foregroundColor(themeManager.textColor)
                    .lineLimit(2)
                
                if let description = assignment.description, !description.isEmpty {
                    Text(stripHTML(description))
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                        .lineLimit(2)
                }
                
                HStack(spacing: 16) {
                    if let dueAt = assignment.dueAt {
                        Label(formatDate(dueAt), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(assignment.isOverdue ? .red : themeManager.secondaryTextColor)
                    }
                    
                    if let points = assignment.pointsPossible {
                        Label("\(Int(points)) pts", systemImage: "star")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                    
                    Spacer()
                    
                    AssignmentStatusBadge(assignment: assignment)
                }
            }
        }
        .padding()
        .background(themeManager.surfaceColor)
        .cornerRadius(12)
    }
    
    private var assignmentIcon: String {
        if let types = assignment.submissionTypes, !types.isEmpty {
            switch types.first {
            case "online_text_entry": return "doc.text.fill"
            case "online_upload": return "doc.fill"
            case "online_url": return "link"
            case "online_quiz": return "questionmark.circle.fill"
            default: return "doc.on.doc.fill"
            }
        }
        return "doc.on.doc.fill"
    }
    
    private func stripHTML(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
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

