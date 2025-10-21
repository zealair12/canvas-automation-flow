//
//  DashboardView.swift
//  CanvasAutomationFlow
//
//  Created on 2025-09-14.
//

import SwiftUI
import WebKit

struct DashboardView: View {
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
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
    @EnvironmentObject var themeManager: ThemeManager
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
                            HStack(spacing: 12) {
                                Button("Download PDF") {
                                    downloadAsPDF(content: response, title: "AI Explanation")
                                }
                                .font(.caption)
                                .foregroundColor(.orange)
                                
                                Button("Copy") {
                                    UIPasteboard.general.string = response
                                }
                                .font(.caption)
                                .foregroundColor(.orange)
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
    
    private func downloadAsPDF(content: String, title: String) {
        print("🚀 Starting PDF download for: \(title)")
        print("📝 Content length: \(content.count) characters")
        
        // Create PDF from HTML content
        let htmlContent = generatePDFHTML(from: content, title: title)
        print("📄 HTML content generated, length: \(htmlContent.count) characters")
        
        // Create PDF data using WebKit
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 1000))
        print("🌐 WebView created")
        
        webView.loadHTMLString(htmlContent, baseURL: nil as URL?)
        print("📖 HTML loaded into WebView")
        
        // Wait for content to load, then create PDF
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("⏰ Starting PDF generation...")
            let pdfConfiguration = WKPDFConfiguration()
            pdfConfiguration.rect = CGRect(x: 0, y: 0, width: 800, height: 1000)
            
            webView.createPDF(configuration: pdfConfiguration) { result in
                print("📄 PDF generation completed")
                switch result {
                case .success(let data):
                    print("✅ PDF created successfully, size: \(data.count) bytes")
                    
                    // Save to documents directory
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let fileName = "\(title.replacingOccurrences(of: " ", with: "_"))_\(Date().timeIntervalSince1970).pdf"
                    let fileURL = documentsPath.appendingPathComponent(fileName)
                    
                    do {
                        try data.write(to: fileURL)
                        
                        // Debug: Print file location for testing
                        print("📄 PDF saved to: \(fileURL.path)")
                        print("📄 PDF file exists: \(FileManager.default.fileExists(atPath: fileURL.path))")
                        print("📄 PDF size: \(data.count) bytes")
                        
                        // Share the PDF
                        DispatchQueue.main.async {
                            print("📤 Presenting share sheet...")
                            let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first {
                                window.rootViewController?.present(activityViewController, animated: true)
                                print("✅ Share sheet presented")
                            } else {
                                print("❌ Could not find window to present share sheet")
                            }
                        }
                    } catch {
                        print("❌ Error saving PDF: \(error)")
                    }
                case .failure(let error):
                    print("❌ PDF creation failed: \(error)")
                }
            }
        }
    }
    
    private func generatePDFHTML(from content: String, title: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>\(title)</title>
            <style>
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; 
                    color: #000; 
                    background: #fff; 
                    padding: 20px; 
                    margin: 0; 
                    line-height: 1.6;
                }
                h1, h2, h3, h4, h5, h6 { 
                    color: #000; 
                    margin-top: 1.5em; 
                    margin-bottom: 0.5em; 
                }
                p { 
                    color: #000; 
                    margin-bottom: 1em; 
                }
                ul, ol { 
                    color: #000; 
                    margin-bottom: 1em;
                }
                li { 
                    color: #000; 
                    margin-bottom: 0.25em; 
                }
                strong { 
                    color: #000; 
                    font-weight: 600; 
                }
                em { 
                    color: #000; 
                    font-style: italic; 
                }
                table { 
                    border-collapse: collapse; 
                    width: 100%; 
                    margin: 1em 0; 
                }
                th, td { 
                    border: 1px solid #ddd; 
                    padding: 8px; 
                    text-align: left; 
                    color: #000; 
                }
                th { 
                    background-color: #f5f5f5; 
                    font-weight: 600; 
                }
                tr:nth-child(even) { 
                    background-color: #f9f9f9; 
                }
                hr { 
                    border: none; 
                    border-top: 1px solid #ddd; 
                    margin: 1em 0; 
                }
                code { 
                    background: rgba(0,0,0,0.1); 
                    padding: 2px 4px; 
                    border-radius: 4px; 
                    font-family: 'Courier New', monospace;
                }
            </style>
        </head>
        <body>
            <h1>\(title)</h1>
            \(processMarkdownForPDF(content))
        </body>
        </html>
        """
    }
    
    private func processMarkdownForPDF(_ markdown: String) -> String {
        var html = markdown
        
        // Process tables first
        html = processTables(html)
        
        // Convert headers
        html = html.replacingOccurrences(of: "### ", with: "<h3>")
        html = html.replacingOccurrences(of: "## ", with: "<h2>")
        html = html.replacingOccurrences(of: "# ", with: "<h1>")
        html = html.replacingOccurrences(of: "\n", with: "</h3>\n", options: [], range: html.range(of: "<h3>"))
        html = html.replacingOccurrences(of: "\n", with: "</h2>\n", options: [], range: html.range(of: "<h2>"))
        html = html.replacingOccurrences(of: "\n", with: "</h1>\n", options: [], range: html.range(of: "<h1>"))
        
        // Convert bold **text**
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        
        // Convert italic *text*
        html = html.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)
        
        // Convert inline code `code`
        html = html.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)
        
        // Convert lists
        let lines = html.components(separatedBy: "\n")
        var processedLines: [String] = []
        var inList = false
        
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("- ") {
                if !inList {
                    processedLines.append("<ul>")
                    inList = true
                }
                let item = line.replacingOccurrences(of: "^- ", with: "", options: .regularExpression)
                processedLines.append("<li>\(item)</li>")
            } else {
                if inList {
                    processedLines.append("</ul>")
                    inList = false
                }
                processedLines.append(line)
            }
        }
        
        if inList {
            processedLines.append("</ul>")
        }
        
        html = processedLines.joined(separator: "\n")
        
        // Convert horizontal rules
        html = html.replacingOccurrences(of: "\n---\n", with: "\n<hr>\n")
        html = html.replacingOccurrences(of: "\n---", with: "\n<hr>")
        html = html.replacingOccurrences(of: "---\n", with: "<hr>\n")
        
        // Convert paragraphs
        html = html.replacingOccurrences(of: "\n\n", with: "</p><p>")
        html = "<p>" + html + "</p>"
        
        // Clean up empty paragraphs
        html = html.replacingOccurrences(of: "<p></p>", with: "")
        html = html.replacingOccurrences(of: "<p> </p>", with: "")
        
        return html
    }
    
    private func processTables(_ html: String) -> String {
        let lines = html.components(separatedBy: "\n")
        var processedLines: [String] = []
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            
            // Check if this line looks like a table header (contains |)
            if line.contains("|") && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                var tableLines: [String] = []
                
                // Collect all consecutive table lines
                while i < lines.count && lines[i].contains("|") && !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                    tableLines.append(lines[i])
                    i += 1
                }
                
                if tableLines.count >= 2 {
                    // Convert to HTML table
                    let tableHTML = convertTableToHTML(tableLines)
                    processedLines.append(tableHTML)
                } else {
                    // Not enough lines for a table, add as regular lines
                    processedLines.append(contentsOf: tableLines)
                }
                
                i -= 1 // Adjust for the loop increment
            } else {
                processedLines.append(line)
            }
            
            i += 1
        }
        
        return processedLines.joined(separator: "\n")
    }
    
    private func convertTableToHTML(_ tableLines: [String]) -> String {
        var html = "<table>\n"
        
        for (index, line) in tableLines.enumerated() {
            let cells = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            
            if index == 1 {
                // Skip separator line (usually contains dashes)
                continue
            }
            
            if !cells.isEmpty {
                let tag = index == 0 ? "th" : "td"
                html += "  <tr>\n"
                for cell in cells {
                    html += "    <\(tag)>\(cell)</\(tag)>\n"
                }
                html += "  </tr>\n"
            }
        }
        
        html += "</table>"
        return html
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
