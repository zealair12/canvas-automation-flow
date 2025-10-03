//
//  AssignmentDetailView.swift
//  CanvasAutomationFlow
//
//  Created on 2025-09-29.
//

import SwiftUI
import WebKit

struct AssignmentDetailView: View {
    let assignment: Assignment
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingAIHelp = false
    @State private var aiQuestion = ""
    @State private var aiResponse = ""
    @State private var isLoadingAI = false
    @State private var uploadedFiles: [File] = []
    @State private var showingSubmission = false
    @State private var showingTextSubmission = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Assignment Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(assignment.name)
                            .futuristicFont(.futuristicTitle)
                            .foregroundColor(themeManager.textColor)
                            .multilineTextAlignment(.leading)
                        
                        HStack {
                            if let dueAt = assignment.dueAt {
                                Label(formatDate(dueAt), systemImage: "calendar")
                                    .foregroundColor(assignment.isOverdue ? .red : themeManager.accentColor)
                            }
                            
                            Spacer()
                            
                            if let points = assignment.pointsPossible {
                                Label("\(Int(points)) pts", systemImage: "star.fill")
                                    .foregroundColor(themeManager.accentColor)
                            }
                        }
                        .futuristicFont(.futuristicCaption)
                        
                        AssignmentStatusBadge(assignment: assignment)
                    }
                    .padding()
                    .futuristicCard()
                    
                    // Assignment Description - Centered and Full Width
                    if let description = assignment.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .futuristicFont(.futuristicHeadline)
                                .foregroundColor(themeManager.accentColor)
                            
                            HTMLTextView(htmlContent: description)
                                .frame(height: 300)
                                .background(themeManager.surfaceColor)
                                .cornerRadius(8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .futuristicCard()
                        .padding(.horizontal, 20)
                    }
                    
                    // Submission Types - Full Screen Width
                    if !assignment.submissionTypes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How to Submit")
                                .futuristicFont(.futuristicHeadline)
                                .foregroundColor(themeManager.accentColor)
                            
                            ForEach(assignment.submissionTypes, id: \.self) { type in
                                Label(friendlySubmissionTypeName(type), systemImage: iconForSubmissionType(type))
                                    .foregroundColor(themeManager.textColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .futuristicCard()
                    }
                    
                    // File upload functionality moved to AI Assignment Help
                    
                    // Action Buttons - Centered and Full Width
                    VStack(spacing: 16) {
                        FuturisticButton(title: "AI Help & Analysis") {
                            showingAIHelp = true
                        }
                        .frame(maxWidth: .infinity)
                        
                        if assignment.submissionTypes.contains("online_upload") {
                            FuturisticButton(title: "Submit Files") {
                                showingSubmission = true
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        if assignment.submissionTypes.contains("online_text_entry") {
                            FuturisticButton(title: "Submit Text") {
                                showingTextSubmission = true
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAIHelp) {
            AssignmentAIHelpView(
                assignment: assignment,
                contextFiles: [],
                question: $aiQuestion,
                response: $aiResponse,
                isLoading: $isLoadingAI,
                apiService: apiService
            )
        }
        .sheet(isPresented: $showingSubmission) {
            AssignmentSubmissionView(
                assignment: assignment,
                submissionType: .fileUpload,
                apiService: apiService
            )
        }
        .sheet(isPresented: $showingTextSubmission) {
            AssignmentSubmissionView(
                assignment: assignment,
                submissionType: .textEntry,
                apiService: apiService
            )
        }
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
    
    private func iconForSubmissionType(_ type: String) -> String {
        switch type {
        case "online_upload": return "arrow.up.doc"
        case "online_text_entry": return "text.cursor"
        case "online_url": return "link"
        case "discussion_topic": return "bubble.left.and.bubble.right"
        case "external_tool": return "wrench.and.screwdriver"
        default: return "doc"
        }
    }
    
    private func friendlySubmissionTypeName(_ type: String) -> String {
        switch type.lowercased() {
        case "online_text_entry": return "Text Entry (Type your answer)"
        case "online_upload": return "File Upload (Upload documents/files)"
        case "online_url": return "URL Submission (Submit a web link)"
        case "on_paper": return "On Paper (Submit physically)"
        case "discussion_topic": return "Discussion Post"
        case "external_tool": return "External Tool"
        default: return type.capitalized
        }
    }
    
}

struct HTMLTextView: UIViewRepresentable {
    let htmlContent: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = UIColor.clear
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = true
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
                    line-height: 1.5;
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
    }
}

struct AssignmentAIHelpView: View {
    let assignment: Assignment
    let contextFiles: [File]
    @Binding var question: String
    @Binding var response: String
    @Binding var isLoading: Bool
    let apiService: APIService
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedHelpType: AIHelpType = .analysis
    
    enum AIHelpType: String, CaseIterable {
        case analysis = "Analysis"
        case guidance = "Guidance"
        case research = "Research"
        case solution = "Solution"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Assignment Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(assignment.name)
                        .futuristicFont(.futuristicHeadline)
                        .foregroundColor(themeManager.textColor)
                    
                    if !contextFiles.isEmpty {
                        Text("Context: \(contextFiles.count) files uploaded")
                            .futuristicFont(.futuristicCaption)
                            .foregroundColor(themeManager.accentColor)
                    }
                }
                .padding()
                .futuristicCard()
                
                // Help Type Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Help Type")
                        .futuristicFont(.futuristicHeadline)
                        .foregroundColor(themeManager.textColor)
                    
                    Picker("Help Type", selection: $selectedHelpType) {
                        ForEach(AIHelpType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding()
                .futuristicCard()
                
                // Question Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Question")
                        .futuristicFont(.futuristicHeadline)
                        .foregroundColor(themeManager.textColor)
                    
                    TextEditor(text: $question)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(themeManager.surfaceColor)
                        .cornerRadius(8)
                        .foregroundColor(themeManager.textColor)
                }
                .padding()
                .futuristicCard()
                
                // Get Help Button
                FuturisticButton(title: isLoading ? "Getting Help..." : "Get AI Help") {
                    Task {
                        await getAIHelp()
                    }
                }
                .disabled(isLoading || question.isEmpty)
                
                // Response
                if !response.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("AI Response")
                                .futuristicFont(.futuristicHeadline)
                                .foregroundColor(themeManager.accentColor)
                            
                            Spacer()
                            
                            Button(action: {
                                UIPasteboard.general.string = response
                            }) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy")
                            }
                            .futuristicFont(.futuristicCaption)
                            .foregroundColor(themeManager.accentColor)
                        }
                        
                        ScrollView {
                            MarkdownView(content: response, sources: nil)
                                .padding()
                        }
                        .frame(maxHeight: 300)
                        .background(themeManager.surfaceColor)
                        .cornerRadius(8)
                    }
                    .padding()
                    .futuristicCard()
                }
                
                Spacer()
            }
            .padding()
            .background(themeManager.backgroundColor)
            .navigationTitle("AI Help")
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
        isLoading = true
        response = ""
        
        let contextInfo = contextFiles.map { "File: \($0.displayName)" }.joined(separator: "\n")
        let fullQuestion = question + (contextInfo.isEmpty ? "" : "\n\nContext files:\n\(contextInfo)")
        
        // Map help type to API parameter
        let helpTypeParam = selectedHelpType.rawValue.lowercased()
        
        let helpResponse = await apiService.getAssignmentHelpWithFiles(
            assignmentId: assignment.canvasAssignmentId,
            courseId: assignment.courseId,
            question: fullQuestion,
            files: contextFiles,
            helpType: helpTypeParam
        )
        
        if let result = helpResponse {
            response = result.content
            // Store sources for citation display
            if let sources = result.sources {
                // Sources will be handled by MarkdownView
                print("Received \(sources.count) sources")
            }
        } else {
            response = "Sorry, I couldn't get help for this assignment. Please try again."
        }
        
        isLoading = false
    }
}

struct AssignmentFileUploadView: View {
    let assignment: Assignment
    @Binding var uploadedFiles: [File]
    let apiService: APIService
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingDocumentPicker = false
    @State private var isUploading = false
    @State private var uploadStatus = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Upload files to provide context for AI help")
                    .futuristicFont(.futuristicBody)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .multilineTextAlignment(.center)
                
                FuturisticButton(title: "Select Files") {
                    showingDocumentPicker = true
                }
                .disabled(isUploading)
                
                if isUploading {
                    ProgressView("Uploading...")
                        .foregroundColor(themeManager.textColor)
                }
                
                if !uploadStatus.isEmpty {
                    Text(uploadStatus)
                        .foregroundColor(uploadStatus.contains("✅") ? .green : .red)
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .background(themeManager.backgroundColor)
            .navigationTitle("Upload Context")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.data, .pdf, .text, .image],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                await uploadFiles(urls)
            }
        case .failure(let error):
            uploadStatus = "File selection failed: \(error.localizedDescription)"
        }
    }
    
    private func uploadFiles(_ urls: [URL]) async {
        isUploading = true
        uploadStatus = ""
        
        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                let fileName = url.lastPathComponent
                
                if let file = await apiService.uploadFile(
                    data: data,
                    fileName: fileName,
                    folderPath: "assignment_context/\(assignment.canvasAssignmentId)"
                ) {
                    uploadedFiles.append(file)
                    uploadStatus = "✅ Uploaded \(uploadedFiles.count) files"
                }
            } catch {
                uploadStatus = "Error uploading \(url.lastPathComponent): \(error.localizedDescription)"
            }
        }
        
        isUploading = false
    }
}

struct AIResponseView: View {
    let content: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(parseResponseWithSources(content), id: \.id) { item in
                switch item.type {
                case .text:
                    Text(item.content)
                        .futuristicFont(.futuristicBody)
                        .foregroundColor(themeManager.textColor)
                case .source:
                    if let url = URL(string: item.content) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "link")
                                Text(extractDomainFromURL(item.content))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .padding(8)
                            .background(themeManager.accentColor.opacity(0.2))
                            .foregroundColor(themeManager.accentColor)
                            .cornerRadius(6)
                        }
                    }
                }
            }
        }
    }
    
    private func parseResponseWithSources(_ content: String) -> [ResponseItem] {
        var items: [ResponseItem] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            if line.contains("http://") || line.contains("https://") {
                // Extract URL from line
                let urlPattern = #"https?://[^\s]+"#
                if let range = line.range(of: urlPattern, options: .regularExpression) {
                    let url = String(line[range])
                    items.append(ResponseItem(type: .source, content: url))
                }
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                items.append(ResponseItem(type: .text, content: line))
            }
        }
        
        return items
    }
    
    private func extractDomainFromURL(_ urlString: String) -> String {
        if let url = URL(string: urlString) {
            return url.host ?? urlString
        }
        return urlString
    }
}

struct ResponseItem {
    let id = UUID()
    let type: ResponseType
    let content: String
    
    enum ResponseType {
        case text
        case source
    }
}

#Preview {
    AssignmentDetailView(assignment: Assignment(
        id: "test",
        canvasAssignmentId: "123",
        courseId: "456",
        name: "Test Assignment",
        description: "<p>This is a <strong>test</strong> assignment with <a href='#'>links</a>.</p>",
        dueAt: "2025-10-01T23:59:59Z",
        pointsPossible: 100,
        gradingType: "points",
        submissionTypes: ["online_upload", "online_text_entry"],
        allowedExtensions: ["pdf", "docx"],
        status: "published"
    ))
    .environmentObject(APIService())
    .environmentObject(ThemeManager())
}
