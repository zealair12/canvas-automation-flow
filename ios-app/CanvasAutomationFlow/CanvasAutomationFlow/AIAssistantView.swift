import SwiftUI

struct AIAssistantView: View {
    @EnvironmentObject var apiService: APIService
    @State private var selectedFeature: AIFeature = .assignmentHelp
    @State private var inputText = ""
    @State private var contextText = ""
    @State private var selectedAssignment: Assignment?
    @State private var selectedCourses: Set<Course> = []
    @State private var aiResponse = ""
    @State private var isLoading = false
    @State private var showingAssignmentPicker = false
    @State private var showingCoursePicker = false
    @State private var selectedLevel = "undergraduate"
    @State private var selectedFeedbackType = "constructive"
    
    enum AIFeature: String, CaseIterable {
        case assignmentHelp = "Assignment Help"
        case studyPlan = "Study Plan"
        case conceptExplainer = "Concept Explainer"
        case feedbackDraft = "Feedback Draft"
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // AI Feature Selector
                Picker("AI Feature", selection: $selectedFeature) {
                    ForEach(AIFeature.allCases, id: \.self) { feature in
                        Text(feature.rawValue).tag(feature)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Feature-specific input
                        featureInputSection
                        
                        // AI Response
                        if !aiResponse.isEmpty {
                            aiResponseSection
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("AI Assistant")
            .task {
                if apiService.isAuthenticated {
                    await loadData()
                }
            }
        }
    }
    
    @ViewBuilder
    private var featureInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch selectedFeature {
            case .assignmentHelp:
                assignmentHelpSection
            case .studyPlan:
                studyPlanSection
            case .conceptExplainer:
                conceptExplainerSection
            case .feedbackDraft:
                feedbackDraftSection
            }
            
            // Generate Button
            Button(action: {
                Task {
                    await generateAIResponse()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isLoading ? "Generating..." : "Generate with AI")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isLoading || !canGenerate)
        }
    }
    
    @ViewBuilder
    private var assignmentHelpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assignment Help")
                .font(.headline)
            
            // Assignment Picker
            Button(action: {
                showingAssignmentPicker = true
            }) {
                HStack {
                    Text(selectedAssignment?.name ?? "Select Assignment")
                        .foregroundColor(selectedAssignment == nil ? .gray : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .sheet(isPresented: $showingAssignmentPicker) {
                AssignmentPickerView(selectedAssignment: $selectedAssignment, assignments: apiService.assignments)
            }
            
            // Question Input
            Text("Your Question:")
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField("What do you need help with?", text: $inputText, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
        }
    }
    
    @ViewBuilder
    private var studyPlanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Study Plan Generator")
                .font(.headline)
            
            // Course Selection
            Button(action: {
                showingCoursePicker = true
            }) {
                HStack {
                    Text(selectedCourses.isEmpty ? "Select Courses" : "\(selectedCourses.count) courses selected")
                        .foregroundColor(selectedCourses.isEmpty ? .gray : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .sheet(isPresented: $showingCoursePicker) {
                CoursePickerView(selectedCourses: $selectedCourses, courses: apiService.courses)
            }
            
            // Days ahead slider
            VStack(alignment: .leading) {
                Text("Plan for next \(Int(inputText) ?? 7) days")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Slider(value: Binding(
                    get: { Double(inputText) ?? 7 },
                    set: { inputText = String(Int($0)) }
                ), in: 1...30, step: 1)
            }
        }
    }
    
    @ViewBuilder
    private var conceptExplainerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Concept Explainer")
                .font(.headline)
            
            // Concept Input
            TextField("Enter concept to explain", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            // Context Input
            TextField("Additional context (optional)", text: $contextText, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(2...4)
            
            // Level Picker
            Picker("Explanation Level", selection: $selectedLevel) {
                Text("Beginner").tag("beginner")
                Text("Undergraduate").tag("undergraduate")
                Text("Graduate").tag("graduate")
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    @ViewBuilder
    private var feedbackDraftSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feedback Draft Generator")
                .font(.headline)
            
            // Assignment Picker
            Button(action: {
                showingAssignmentPicker = true
            }) {
                HStack {
                    Text(selectedAssignment?.name ?? "Select Assignment")
                        .foregroundColor(selectedAssignment == nil ? .gray : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .sheet(isPresented: $showingAssignmentPicker) {
                AssignmentPickerView(selectedAssignment: $selectedAssignment, assignments: apiService.assignments)
            }
            
            // Submission Content
            Text("Submission Content:")
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField("Enter submission content", text: $inputText, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(4...8)
            
            // Feedback Type
            Picker("Feedback Style", selection: $selectedFeedbackType) {
                Text("Constructive").tag("constructive")
                Text("Detailed").tag("detailed")
                Text("Encouraging").tag("encouraging")
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    @ViewBuilder
    private var aiResponseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI Response")
                    .font(.headline)
                Spacer()
                Button("Copy") {
                    UIPasteboard.general.string = aiResponse
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            FormattedText(aiResponse)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .textSelection(.enabled)
        }
    }
    
    private var canGenerate: Bool {
        switch selectedFeature {
        case .assignmentHelp:
            return selectedAssignment != nil && !inputText.isEmpty
        case .studyPlan:
            return !selectedCourses.isEmpty
        case .conceptExplainer:
            return !inputText.isEmpty
        case .feedbackDraft:
            return selectedAssignment != nil && !inputText.isEmpty
        }
    }
    
    private func generateAIResponse() async {
        isLoading = true
        aiResponse = ""
        
        let response: String?
        
        switch selectedFeature {
        case .assignmentHelp:
            response = await apiService.getAssignmentHelp(
                assignmentId: selectedAssignment?.canvasAssignmentId ?? "",
                question: inputText
            )
        case .studyPlan:
            let courseIds = selectedCourses.map { $0.canvasCourseId }
            response = await apiService.generateStudyPlan(
                courseIds: courseIds,
                daysAhead: Int(inputText) ?? 7
            )
        case .conceptExplainer:
            response = await apiService.explainConcept(
                concept: inputText,
                context: contextText,
                level: selectedLevel
            )
        case .feedbackDraft:
            response = await apiService.generateFeedbackDraft(
                assignmentId: selectedAssignment?.canvasAssignmentId ?? "",
                submissionContent: inputText,
                feedbackType: selectedFeedbackType
            )
        }
        
        aiResponse = response ?? "Sorry, I couldn't generate a response. Please try again."
        isLoading = false
    }
    
    private func loadData() async {
        await apiService.fetchCourses()
        if let firstCourse = apiService.courses.first {
            await apiService.fetchAssignments(for: firstCourse.canvasCourseId)
        }
    }
}

// MARK: - Helper Views

struct AssignmentPickerView: View {
    @Binding var selectedAssignment: Assignment?
    let assignments: [Assignment]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(assignments) { assignment in
                Button(action: {
                    selectedAssignment = assignment
                    dismiss()
                }) {
                    VStack(alignment: .leading) {
                        Text(assignment.name)
                            .foregroundColor(.primary)
                        if let points = assignment.pointsPossible {
                            Text("\(Int(points)) points")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Select Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CoursePickerView: View {
    @Binding var selectedCourses: Set<Course>
    let courses: [Course]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(courses) { course in
                Button(action: {
                    if selectedCourses.contains(course) {
                        selectedCourses.remove(course)
                    } else {
                        selectedCourses.insert(course)
                    }
                }) {
                    HStack {
                        Text(course.name)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedCourses.contains(course) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Courses")
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
}


#Preview {
    AIAssistantView()
        .environmentObject(APIService())
}
