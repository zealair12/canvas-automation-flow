import Foundation
import Combine

@MainActor
class APIService: ObservableObject {
    private let baseURL = "http://10.27.9.227:5000"
    private var authToken: String?
    
    @Published var isAuthenticated = false
    @Published var user: User?
    @Published var courses: [Course] = []
    @Published var assignments: [Assignment] = []
    @Published var files: [File] = []
    @Published var folders: [Folder] = []
    @Published var reminders: [Reminder] = []
    
    init() {
        // Check if we have a stored token
        if let token = UserDefaults.standard.string(forKey: "canvas_token") {
            self.authToken = token
            self.isAuthenticated = true
            Task {
                await fetchUserProfile()
            }
        }
    }
    
    // MARK: - Authentication
    
    func authenticateWithToken(_ token: String) async -> Bool {
        self.authToken = token
        
        // Test the token by fetching user profile
        let success = await fetchUserProfile()
        
        if success {
            UserDefaults.standard.set(token, forKey: "canvas_token")
            self.isAuthenticated = true
        } else {
            self.authToken = nil
            UserDefaults.standard.removeObject(forKey: "canvas_token")
            self.isAuthenticated = false
        }
        
        return success
    }
    
    func signOut() {
        self.authToken = nil
        self.isAuthenticated = false
        self.user = nil
        self.courses = []
        self.assignments = []
        self.files = []
        self.folders = []
        self.reminders = []
        UserDefaults.standard.removeObject(forKey: "canvas_token")
    }
    
    // MARK: - User Profile
    
    @discardableResult
    func fetchUserProfile() async -> Bool {
        guard let token = authToken else { 
            print("🚨 No auth token available")
            return false 
        }
        
        guard let url = URL(string: "\(baseURL)/api/user/profile") else { 
            print("🚨 Invalid URL: \(baseURL)/api/user/profile")
            return false 
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🔍 Making request to: \(url)")
        print("🔍 Authorization header: Bearer \(token)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 Response status: \(httpResponse.statusCode)")
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
            print("🔍 Response body: \(responseString)")
            
            let user = try JSONDecoder().decode(User.self, from: data)
            self.user = user
            print("✅ Successfully decoded user: \(user.name)")
            return true
        } catch {
            print("🚨 Error fetching user profile: \(error)")
            return false
        }
    }
    
    // MARK: - Courses
    
    func fetchCourses() async {
        guard let token = authToken else { return }
        
        guard let url = URL(string: "\(baseURL)/api/user/courses") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(CoursesResponse.self, from: data)
            self.courses = response.courses
        } catch {
            print("Error fetching courses: \(error)")
        }
    }
    
    // MARK: - Assignments
    
    func fetchAssignments(for courseId: String) async {
        guard let token = authToken else { return }
        
        guard let url = URL(string: "\(baseURL)/api/courses/\(courseId)/assignments") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(AssignmentsResponse.self, from: data)
            self.assignments = response.assignments
        } catch {
            print("Error fetching assignments: \(error)")
        }
    }
    
    func fetchAssignmentDetails(courseId: String, assignmentId: String) async -> Assignment? {
        guard let token = authToken else { return nil }
        
        guard let url = URL(string: "\(baseURL)/api/courses/\(courseId)/assignments/\(assignmentId)") else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(AssignmentResponse.self, from: data)
            return response.assignment
        } catch {
            print("Error fetching assignment details: \(error)")
            return nil
        }
    }
    
    // MARK: - Files
    
    func fetchFiles(for courseId: String, folderId: String? = nil) async {
        guard let token = authToken else { return }
        
        var urlString = "\(baseURL)/api/courses/\(courseId)/files"
        if let folderId = folderId {
            urlString += "?folder_id=\(folderId)"
        }
        
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(FilesResponse.self, from: data)
            self.files = response.files
        } catch {
            print("Error fetching files: \(error)")
        }
    }
    
    func fetchFileDetails(courseId: String, fileId: String) async -> File? {
        guard let token = authToken else { return nil }
        
        guard let url = URL(string: "\(baseURL)/api/courses/\(courseId)/files/\(fileId)") else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(FileResponse.self, from: data)
            return response.file
        } catch {
            print("Error fetching file details: \(error)")
            return nil
        }
    }
    
    func fetchFolders(for courseId: String) async {
        guard let token = authToken else { return }
        
        guard let url = URL(string: "\(baseURL)/api/courses/\(courseId)/folders") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(FoldersResponse.self, from: data)
            self.folders = response.folders
        } catch {
            print("Error fetching folders: \(error)")
        }
    }
    
    func getFileDownloadInfo(fileId: String, courseId: String) async -> FileDownloadInfo? {
        guard let token = authToken else { return nil }
        
        guard let url = URL(string: "\(baseURL)/api/files/\(fileId)/download?course_id=\(courseId)") else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let downloadInfo = try JSONDecoder().decode(FileDownloadInfo.self, from: data)
            return downloadInfo
        } catch {
            print("Error getting file download info: \(error)")
            return nil
        }
    }
    
    // MARK: - AI-Powered Features
    
    func getAssignmentHelp(assignmentId: String, question: String) async -> String? {
        guard let token = authToken else { return nil }
        
        guard let url = URL(string: "\(baseURL)/api/ai/assignment-help") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "assignment_id": assignmentId,
            "question": question
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let help = json["help"] as? String {
                return help
            }
        } catch {
            print("Error getting assignment help: \(error)")
        }
        
        return nil
    }
    
    func generateStudyPlan(courseIds: [String], daysAhead: Int = 7) async -> String? {
        guard let token = authToken else { return nil }
        
        guard let url = URL(string: "\(baseURL)/api/ai/study-plan") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "course_ids": courseIds,
            "days_ahead": daysAhead
        ] as [String: Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let studyPlan = json["study_plan"] as? String {
                return studyPlan
            }
        } catch {
            print("Error generating study plan: \(error)")
        }
        
        return nil
    }
    
    func explainConcept(concept: String, context: String = "", level: String = "undergraduate") async -> String? {
        guard let token = authToken else { return nil }
        
        guard let url = URL(string: "\(baseURL)/api/ai/explain-concept") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "concept": concept,
            "context": context,
            "level": level
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let explanation = json["explanation"] as? String {
                return explanation
            }
        } catch {
            print("Error explaining concept: \(error)")
        }
        
        return nil
    }
    
    func generateFeedbackDraft(assignmentId: String, submissionContent: String, feedbackType: String = "constructive") async -> String? {
        guard let token = authToken else { return nil }
        
        guard let url = URL(string: "\(baseURL)/api/ai/feedback-draft") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "assignment_id": assignmentId,
            "submission_content": submissionContent,
            "feedback_type": feedbackType
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let feedback = json["feedback"] as? String {
                return feedback
            }
        } catch {
            print("Error generating feedback draft: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Reminders
    
    func fetchReminders() async {
        guard let token = authToken else { return }
        
        guard let url = URL(string: "\(baseURL)/api/reminders") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(RemindersResponse.self, from: data)
            self.reminders = response.reminders
        } catch {
            print("Error fetching reminders: \(error)")
        }
    }
    
    func createReminder(assignmentId: String, courseId: String, hoursBeforeDue: Int = 24) async -> Bool {
        guard let token = authToken else { return false }
        
        guard let url = URL(string: "\(baseURL)/api/reminders") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "assignment_id": assignmentId,
            "course_id": courseId,
            "hours_before_due": hoursBeforeDue
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            print("Error creating reminder: \(error)")
            return false
        }
    }
}

// MARK: - Data Models

struct User: Codable, Identifiable {
    let id: Int
    let name: String
    let email: String
    let role: String
    let lastLogin: String?
    let avatarUrl: String?
    let locale: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, email, role, locale
        case lastLogin = "last_login"
        case avatarUrl = "avatar_url"
    }
}

struct Course: Codable, Identifiable, Hashable {
    let id: String
    let canvasCourseId: String
    let name: String
    let courseCode: String
    let description: String?
    let workflowState: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case canvasCourseId = "canvas_course_id"
        case courseCode = "course_code"
        case workflowState = "workflow_state"
    }
}

struct Assignment: Codable, Identifiable, Hashable {
    let id: String
    let canvasAssignmentId: String
    let courseId: String
    let name: String
    let description: String?
    let dueAt: String?
    let pointsPossible: Double?
    let gradingType: String
    let submissionTypes: [String]
    let allowedExtensions: [String]
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, status
        case canvasAssignmentId = "canvas_assignment_id"
        case courseId = "course_id"
        case dueAt = "due_at"
        case pointsPossible = "points_possible"
        case gradingType = "grading_type"
        case submissionTypes = "submission_types"
        case allowedExtensions = "allowed_extensions"
    }
    
    // Computed properties for assignment status
    var isDueSoon: Bool {
        guard let dueAt = dueAt else { return false }
        let formatter = ISO8601DateFormatter()
        guard let dueDate = formatter.date(from: dueAt) else { return false }
        
        let now = Date()
        let timeInterval = dueDate.timeIntervalSince(now)
        
        // Due soon if within 48 hours and not overdue
        return timeInterval > 0 && timeInterval <= (48 * 60 * 60)
    }
    
    var isOverdue: Bool {
        guard let dueAt = dueAt else { return false }
        let formatter = ISO8601DateFormatter()
        guard let dueDate = formatter.date(from: dueAt) else { return false }
        
        return dueDate < Date()
    }
}

struct File: Codable, Identifiable, Hashable {
    let id: String
    let canvasFileId: String
    let courseId: String
    let folderId: String?
    let displayName: String
    let filename: String
    let contentType: String
    let size: Int
    let url: String
    let thumbnailUrl: String?
    let mimeClass: String
    let locked: Bool
    let hidden: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, size, url, locked, hidden
        case canvasFileId = "canvas_file_id"
        case courseId = "course_id"
        case folderId = "folder_id"
        case displayName = "display_name"
        case filename
        case contentType = "content_type"
        case thumbnailUrl = "thumbnail_url"
        case mimeClass = "mime_class"
    }
    
    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    
    var fileExtension: String {
        URL(fileURLWithPath: displayName).pathExtension.lowercased()
    }
    
    var isImage: Bool {
        ["png", "jpg", "jpeg", "gif", "webp", "svg"].contains(fileExtension)
    }
    
    var isPDF: Bool {
        fileExtension == "pdf"
    }
    
    var isDocument: Bool {
        ["doc", "docx", "txt", "rtf"].contains(fileExtension)
    }
    
    var isPresentation: Bool {
        ["ppt", "pptx", "key"].contains(fileExtension)
    }
}

struct Folder: Codable, Identifiable, Hashable {
    let id: String
    let canvasFolderId: String
    let name: String
    let fullName: String
    let parentFolderId: String?
    let filesCount: Int
    let foldersCount: Int
    let locked: Bool
    let hidden: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, locked, hidden
        case canvasFolderId = "canvas_folder_id"
        case fullName = "full_name"
        case parentFolderId = "parent_folder_id"
        case filesCount = "files_count"
        case foldersCount = "folders_count"
    }
}

struct FileDownloadInfo: Codable {
    let downloadUrl: String
    let filename: String
    let contentType: String
    let size: Int
    
    enum CodingKeys: String, CodingKey {
        case filename, size
        case downloadUrl = "download_url"
        case contentType = "content_type"
    }
}

struct Reminder: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let assignmentId: String
    let message: String
    let scheduledFor: String
    let status: String
    let notificationType: String
    
    enum CodingKeys: String, CodingKey {
        case id, message, status
        case userId = "user_id"
        case assignmentId = "assignment_id"
        case scheduledFor = "scheduled_for"
        case notificationType = "notification_type"
    }
}

// MARK: - Response Models

struct CoursesResponse: Codable {
    let courses: [Course]
}

struct AssignmentsResponse: Codable {
    let assignments: [Assignment]
}

struct AssignmentResponse: Codable {
    let assignment: Assignment
}

struct FilesResponse: Codable {
    let files: [File]
}

struct FileResponse: Codable {
    let file: File
}

struct FoldersResponse: Codable {
    let folders: [Folder]
}

struct RemindersResponse: Codable {
    let reminders: [Reminder]
}