//
//  AssignmentSubmissionView.swift
//  CanvasAutomationFlow
//
//  Created on 2025-09-29.
//

import SwiftUI
import UniformTypeIdentifiers

struct AssignmentSubmissionView: View {
    let assignment: Assignment
    let submissionType: SubmissionType
    let apiService: APIService
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var textContent = ""
    @State private var comment = ""
    @State private var selectedFiles: [File] = []
    @State private var urlSubmission = ""
    @State private var isSubmitting = false
    @State private var submissionResult = ""
    @State private var showingDocumentPicker = false
    
    enum SubmissionType {
        case textEntry
        case fileUpload
        case urlSubmission
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Assignment Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(assignment.name)
                        .futuristicFont(.futuristicHeadline)
                        .foregroundColor(themeManager.textColor)
                    
                    if let points = assignment.pointsPossible {
                        Text("\(Int(points)) points possible")
                            .futuristicFont(.futuristicCaption)
                            .foregroundColor(themeManager.accentColor)
                    }
                }
                .padding()
                .futuristicCard()
                
                // Submission Content
                switch submissionType {
                case .textEntry:
                    textEntrySection
                case .fileUpload:
                    fileUploadSection
                case .urlSubmission:
                    urlSubmissionSection
                }
                
                // Comment Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Comment (Optional)")
                        .futuristicFont(.futuristicHeadline)
                        .foregroundColor(themeManager.textColor)
                    
                    TextEditor(text: $comment)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(themeManager.surfaceColor)
                        .cornerRadius(8)
                        .foregroundColor(themeManager.textColor)
                }
                .padding()
                .futuristicCard()
                
                // Submit Button
                FuturisticButton(title: isSubmitting ? "Submitting..." : "Submit Assignment") {
                    Task {
                        await submitAssignment()
                    }
                }
                .disabled(isSubmitting || !canSubmit)
                
                // Submission Result
                if !submissionResult.isEmpty {
                    Text(submissionResult)
                        .foregroundColor(submissionResult.contains("✅") ? .green : .red)
                        .padding()
                        .background(themeManager.surfaceColor)
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .background(themeManager.backgroundColor)
            .navigationTitle("Submit Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: allowedFileTypes,
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
    }
    
    @ViewBuilder
    private var textEntrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Answer")
                .futuristicFont(.futuristicHeadline)
                .foregroundColor(themeManager.textColor)
            
            ZStack(alignment: .topLeading) {
                if textContent.isEmpty {
                    Text("Type your answer here...")
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                }
                
                TextEditor(text: $textContent)
                    .frame(minHeight: 200)
                    .padding(4)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding()
        .futuristicCard()
    }
    
    @ViewBuilder
    private var fileUploadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upload Files")
                .futuristicFont(.futuristicHeadline)
                .foregroundColor(themeManager.textColor)
            
            FuturisticButton(title: "Select Files") {
                showingDocumentPicker = true
            }
            
            if !selectedFiles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Files:")
                        .futuristicFont(.futuristicCaption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    ForEach(selectedFiles) { file in
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(themeManager.accentColor)
                            Text(file.displayName)
                                .foregroundColor(themeManager.textColor)
                                .font(.caption)
                            Spacer()
                            Button(action: {
                                selectedFiles.removeAll { $0.id == file.id }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .futuristicCard()
    }
    
    @ViewBuilder
    private var urlSubmissionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Submission URL")
                .futuristicFont(.futuristicHeadline)
                .foregroundColor(themeManager.textColor)
            
            TextField("Enter URL...", text: $urlSubmission)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .foregroundColor(themeManager.textColor)
        }
        .padding()
        .futuristicCard()
    }
    
    private var canSubmit: Bool {
        switch submissionType {
        case .textEntry:
            return !textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .fileUpload:
            return !selectedFiles.isEmpty
        case .urlSubmission:
            return !urlSubmission.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private var allowedFileTypes: [UTType] {
        if assignment.allowedExtensions.isEmpty {
            return [.data, .pdf, .text, .image, .audio, .video]
        } else {
            // Convert file extensions to UTTypes
            var types: [UTType] = []
            for ext in assignment.allowedExtensions {
                switch ext.lowercased() {
                case "pdf": types.append(.pdf)
                case "doc", "docx": types.append(.data)
                case "txt": types.append(.text)
                case "jpg", "jpeg", "png", "gif": types.append(.image)
                case "mp3", "wav": types.append(.audio)
                case "mp4", "mov": types.append(.video)
                default: types.append(.data)
                }
            }
            return types.isEmpty ? [.data] : types
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                await uploadSelectedFiles(urls)
            }
        case .failure(let error):
            submissionResult = "File selection failed: \(error.localizedDescription)"
        }
    }
    
    private func uploadSelectedFiles(_ urls: [URL]) async {
        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                let fileName = url.lastPathComponent
                
                if let file = await apiService.uploadFile(
                    data: data,
                    fileName: fileName,
                    courseId: assignment.courseId,
                    folderPath: "assignment_submissions/\(assignment.canvasAssignmentId)"
                ) {
                    selectedFiles.append(file)
                }
            } catch {
                submissionResult = "Error uploading \(url.lastPathComponent): \(error.localizedDescription)"
            }
        }
    }
    
    private func submitAssignment() async {
        isSubmitting = true
        submissionResult = ""
        
        let success: Bool
        
        switch submissionType {
        case .textEntry:
            success = await apiService.submitAssignmentText(
                courseId: assignment.courseId,
                assignmentId: assignment.canvasAssignmentId,
                textContent: textContent,
                comment: comment
            )
            
        case .fileUpload:
            let fileIds = selectedFiles.map { $0.canvasFileId }
            success = await apiService.submitAssignmentFiles(
                courseId: assignment.courseId,
                assignmentId: assignment.canvasAssignmentId,
                fileIds: fileIds,
                comment: comment
            )
            
        case .urlSubmission:
            success = await apiService.submitAssignmentURL(
                courseId: assignment.courseId,
                assignmentId: assignment.canvasAssignmentId,
                urlSubmission: urlSubmission,
                comment: comment
            )
        }
        
        if success {
            submissionResult = "✅ Assignment submitted successfully!"
            // Auto-dismiss after success
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        } else {
            submissionResult = "❌ Submission failed. Please try again."
        }
        
        isSubmitting = false
    }
}

#Preview {
    AssignmentSubmissionView(
        assignment: Assignment(
            id: "test",
            canvasAssignmentId: "123",
            courseId: "456",
            name: "Test Assignment",
            description: "Test description",
            dueAt: "2025-10-01T23:59:59Z",
            pointsPossible: 100,
            gradingType: "points",
            submissionTypes: ["online_text_entry"],
            allowedExtensions: [],
            status: "published"
        ),
        submissionType: .textEntry,
        apiService: APIService()
    )
    .environmentObject(ThemeManager())
}
