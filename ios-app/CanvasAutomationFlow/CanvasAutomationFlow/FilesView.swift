import SwiftUI

struct FilesView: View {
    @EnvironmentObject var apiService: APIService
    @State private var selectedCourse: Course?
    @State private var selectedFolder: Folder?
    @State private var showingFolderPicker = false
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedFileType: FileType = .all
    
    enum FileType: String, CaseIterable {
        case all = "All Files"
        case images = "Images"
        case documents = "Documents"
        case pdfs = "PDFs"
        case presentations = "Presentations"
        case other = "Other"
    }
    
    var filteredFiles: [File] {
        let files = apiService.files
        
        // Filter by search text
        let searchFiltered = searchText.isEmpty ? files : files.filter { file in
            file.displayName.localizedCaseInsensitiveContains(searchText) ||
            file.filename.localizedCaseInsensitiveContains(searchText)
        }
        
        // Filter by file type
        return selectedFileType == .all ? searchFiltered : searchFiltered.filter { file in
            switch selectedFileType {
            case .all:
                return true
            case .images:
                return file.isImage
            case .documents:
                return file.isDocument
            case .pdfs:
                return file.isPDF
            case .presentations:
                return file.isPresentation
            case .other:
                return !file.isImage && !file.isDocument && !file.isPDF && !file.isPresentation
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Course and Folder Selection
                VStack(spacing: 12) {
                    // Course Picker
                    HStack {
                        Text("Course:")
                            .font(.headline)
                        Spacer()
                        
                        Menu {
                            ForEach(apiService.courses) { course in
                                Button(course.name) {
                                    selectedCourse = course
                                    selectedFolder = nil
                                    Task {
                                        await loadFiles()
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedCourse?.name ?? "Select Course")
                                    .foregroundColor(selectedCourse == nil ? .gray : .primary)
                                Image(systemName: "chevron.down")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Folder Picker (if course selected)
                    if selectedCourse != nil {
                        HStack {
                            Text("Folder:")
                                .font(.headline)
                            Spacer()
                            
                            Menu {
                                Button("All Files") {
                                    selectedFolder = nil
                                    Task {
                                        await loadFiles()
                                    }
                                }
                                
                                ForEach(apiService.folders) { folder in
                                    Button(folder.name) {
                                        selectedFolder = folder
                                        Task {
                                            await loadFiles()
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedFolder?.name ?? "All Files")
                                        .foregroundColor(.primary)
                                    Image(systemName: "chevron.down")
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Search and Filter
                VStack(spacing: 8) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search files...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // File Type Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(FileType.allCases, id: \.self) { fileType in
                                Button(fileType.rawValue) {
                                    selectedFileType = fileType
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedFileType == fileType ? Color.blue : Color(.systemGray6))
                                .foregroundColor(selectedFileType == fileType ? .white : .primary)
                                .cornerRadius(16)
                                .font(.caption)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.horizontal)
                
                // Files List
                if isLoading {
                    Spacer()
                    ProgressView("Loading files...")
                    Spacer()
                } else if selectedCourse == nil {
                    Spacer()
                    VStack {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Select a course to view files")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else if filteredFiles.isEmpty {
                    Spacer()
                    VStack {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text(searchText.isEmpty ? "No files found" : "No files match your search")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    List(filteredFiles) { file in
                        FileRowView(file: file, apiService: apiService)
                    }
                }
            }
            .navigationTitle("Files")
            .task {
                await apiService.fetchCourses()
            }
        }
    }
    
    private func loadFiles() async {
        guard let course = selectedCourse else { return }
        
        isLoading = true
        
        // Load folders first
        await apiService.fetchFolders(for: course.canvasCourseId)
        
        // Load files
        await apiService.fetchFiles(for: course.canvasCourseId, folderId: selectedFolder?.canvasFolderId)
        
        isLoading = false
    }
}

struct FileRowView: View {
    let file: File
    let apiService: APIService
    @State private var isDownloading = false
    
    var body: some View {
        HStack {
            // File Icon
            fileIcon
                .frame(width: 40, height: 40)
            
            // File Info
            VStack(alignment: .leading, spacing: 4) {
                Text(file.displayName)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    Text(file.fileSizeFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(file.mimeClass.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray6))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // Download Button
            Button(action: {
                Task {
                    await downloadFile()
                }
            }) {
                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .disabled(isDownloading)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var fileIcon: some View {
        if file.isImage {
            if let thumbnailUrl = file.thumbnailUrl, let url = URL(string: thumbnailUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "photo")
                        .foregroundColor(.blue)
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "photo")
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
            }
        } else if file.isPDF {
            Image(systemName: "doc.fill")
                .foregroundColor(.red)
                .frame(width: 40, height: 40)
        } else if file.isDocument {
            Image(systemName: "doc.text.fill")
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
        } else if file.isPresentation {
            Image(systemName: "play.rectangle.fill")
                .foregroundColor(.orange)
                .frame(width: 40, height: 40)
        } else {
            Image(systemName: "doc")
                .foregroundColor(.gray)
                .frame(width: 40, height: 40)
        }
    }
    
    private func downloadFile() async {
        isDownloading = true
        
        guard let downloadInfo = await apiService.getFileDownloadInfo(fileId: file.canvasFileId, courseId: file.courseId),
              let url = URL(string: downloadInfo.downloadUrl) else {
            isDownloading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Save to Files app
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent(downloadInfo.filename)
            
            try data.write(to: fileURL)
            
            // Show success (you could add a toast or alert here)
            print("File downloaded to: \(fileURL)")
            
        } catch {
            print("Download error: \(error)")
        }
        
        isDownloading = false
    }
}

#Preview {
    FilesView()
        .environmentObject(APIService())
}
