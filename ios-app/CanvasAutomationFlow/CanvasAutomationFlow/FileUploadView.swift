//
//  FileUploadView.swift
//  CanvasAutomationFlow
//
//  Created on 2025-09-29.
//

import SwiftUI
import UniformTypeIdentifiers

struct FileUploadView: View {
    @EnvironmentObject var apiService: APIService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingDocumentPicker = false
    @State private var showingURLUpload = false
    @State private var selectedCourse: Course?
    @State private var folderPath = ""
    @State private var isUploading = false
    @State private var uploadResult: String = ""
    
    // URL Upload fields
    @State private var fileURL = ""
    @State private var fileName = ""
    @State private var fileSizeString = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Course Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Course")
                        .futuristicFont(.futuristicHeadline)
                        .foregroundColor(themeManager.textColor)
                    
                    Menu {
                        Button("Personal Files") {
                            selectedCourse = nil
                        }
                        
                        ForEach(apiService.courses) { course in
                            Button(course.name) {
                                selectedCourse = course
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedCourse?.name ?? "Personal Files")
                                .foregroundColor(themeManager.textColor)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(themeManager.accentColor)
                        }
                        .padding()
                        .background(themeManager.surfaceColor)
                        .cornerRadius(8)
                    }
                }
                
                // Folder Path
                VStack(alignment: .leading, spacing: 8) {
                    Text("Folder Path (Optional)")
                        .futuristicFont(.futuristicCaption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    TextField("e.g., assignments/homework", text: $folderPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundColor(themeManager.textColor)
                }
                
                // Upload Options
                VStack(spacing: 16) {
                    FuturisticButton(title: "📁 Upload from Device") {
                        showingDocumentPicker = true
                    }
                    .disabled(isUploading)
                    
                    FuturisticButton(title: "🌐 Upload from URL") {
                        showingURLUpload = true
                    }
                    .disabled(isUploading)
                }
                
                // Upload Status
                if isUploading {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Uploading...")
                            .futuristicFont(.futuristicBody)
                            .foregroundColor(themeManager.textColor)
                    }
                    .padding()
                    .background(themeManager.surfaceColor)
                    .cornerRadius(8)
                }
                
                // Upload Result
                if !uploadResult.isEmpty {
                    Text(uploadResult)
                        .futuristicFont(.futuristicBody)
                        .foregroundColor(uploadResult.contains("✅") ? .green : .red)
                        .padding()
                        .background(themeManager.surfaceColor)
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .background(themeManager.backgroundColor)
            .navigationTitle("Upload Files")
            .futuristicFont(.futuristicTitle)
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.data, .pdf, .image, .text, .audio, .video],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .sheet(isPresented: $showingURLUpload) {
            URLUploadSheet(
                fileURL: $fileURL,
                fileName: $fileName,
                fileSizeString: $fileSizeString,
                selectedCourse: selectedCourse,
                folderPath: folderPath,
                isUploading: $isUploading,
                uploadResult: $uploadResult,
                apiService: apiService
            )
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            Task {
                await uploadFile(from: url)
            }
            
        case .failure(let error):
            uploadResult = "❌ File selection failed: \(error.localizedDescription)"
        }
    }
    
    private func uploadFile(from url: URL) async {
        isUploading = true
        uploadResult = ""
        
        do {
            let data = try Data(contentsOf: url)
            let fileName = url.lastPathComponent
            
            let file = await apiService.uploadFile(
                data: data,
                fileName: fileName,
                courseId: selectedCourse?.canvasCourseId,
                folderPath: folderPath.isEmpty ? nil : folderPath
            )
            
            if let file = file {
                uploadResult = "✅ Successfully uploaded: \(file.displayName)"
                // Refresh files list
                if let courseId = selectedCourse?.canvasCourseId {
                    await apiService.fetchFiles(for: courseId)
                }
            } else {
                uploadResult = "❌ Upload failed"
            }
            
        } catch {
            uploadResult = "❌ Error reading file: \(error.localizedDescription)"
        }
        
        isUploading = false
    }
}

struct URLUploadSheet: View {
    @Binding var fileURL: String
    @Binding var fileName: String
    @Binding var fileSizeString: String
    let selectedCourse: Course?
    let folderPath: String
    @Binding var isUploading: Bool
    @Binding var uploadResult: String
    let apiService: APIService
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    FuturisticTextField(title: "File URL", text: $fileURL)
                    FuturisticTextField(title: "File Name", text: $fileName)
                    FuturisticTextField(title: "File Size (bytes)", text: $fileSizeString)
                }
                
                FuturisticButton(title: "Upload from URL") {
                    Task {
                        await uploadFromURL()
                    }
                }
                .disabled(fileURL.isEmpty || fileName.isEmpty || fileSizeString.isEmpty || isUploading)
                
                if isUploading {
                    ProgressView("Uploading...")
                        .foregroundColor(themeManager.textColor)
                }
                
                if !uploadResult.isEmpty {
                    Text(uploadResult)
                        .foregroundColor(uploadResult.contains("✅") ? .green : .red)
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .background(themeManager.backgroundColor)
            .navigationTitle("Upload from URL")
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
    
    private func uploadFromURL() async {
        guard let fileSize = Int(fileSizeString),
              let courseId = selectedCourse?.canvasCourseId else {
            uploadResult = "❌ Invalid input"
            return
        }
        
        isUploading = true
        uploadResult = ""
        
        let file = await apiService.uploadFileFromURL(
            fileURL: fileURL,
            fileName: fileName,
            fileSize: fileSize,
            courseId: courseId,
            folderPath: folderPath.isEmpty ? nil : folderPath
        )
        
        if let file = file {
            uploadResult = "✅ Successfully uploaded: \(file.displayName)"
            // Refresh files list
            await apiService.fetchFiles(for: courseId)
        } else {
            uploadResult = "❌ Upload failed"
        }
        
        isUploading = false
    }
}

#Preview {
    FileUploadView()
        .environmentObject(APIService())
        .environmentObject(ThemeManager())
}
