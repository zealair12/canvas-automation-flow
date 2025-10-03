# Canvas Automation Flow - Comprehensive Architecture & Implementation Guide

## Executive Summary

This document provides a complete architectural overview, implementation details, and future enhancements for the Canvas Automation Flow system. The system has evolved from a basic Canvas integration to a sophisticated AI-powered academic assistant with assignment submission capabilities.

---

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Backend Architecture](#backend-architecture)
3. [Frontend Architecture](#frontend-architecture)
4. [Key Data Flows](#key-data-flows)
5. [Implementation Evolution](#implementation-evolution)
6. [Current Features](#current-features)
7. [Upcoming Enhancements](#upcoming-enhancements)
8. [Technical Stack](#technical-stack)
9. [Security & Reliability](#security--reliability)
10. [Deployment Architecture](#deployment-architecture)

---

## 1. System Architecture

### 1.1 High-Level Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS Client Layer                         │
│  ┌──────────┬──────────┬──────────┬──────────┬─────────────┐   │
│  │Dashboard │ Courses  │Assignments│   AI    │   Files     │   │
│  │          │          │          │Assistant │             │   │
│  └──────────┴──────────┴──────────┴──────────┴─────────────┘   │
│                         ↕ HTTPS/REST API ↕                       │
└─────────────────────────────────────────────────────────────────┘
                                ↕
┌─────────────────────────────────────────────────────────────────┐
│                      Python Flask Backend                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  API Layer (Flask Routes)                                │   │
│  │  ┌────────┬────────┬────────┬────────┬──────────────┐   │   │
│  │  │  Auth  │Courses │Assigns │  AI   │  Files/Upload│   │   │
│  │  └────────┴────────┴────────┴────────┴──────────────┘   │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Service Layer                                           │   │
│  │  ┌───────────┬──────────┬──────────┬──────────────┐     │   │
│  │  │LLM Service│ Canvas   │  Sync    │ Notification │     │   │
│  │  │(Dual API) │ Client   │ Service  │   Service    │     │   │
│  │  └───────────┴──────────┴──────────┴──────────────┘     │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Integration Layer                                       │   │
│  │  ┌────────────┬──────────────┬────────────────────┐     │   │
│  │  │   Canvas   │   GROQ API   │  Perplexity API    │     │   │
│  │  │  LMS API   │(Calculations)│  (Fact Search)     │     │   │
│  │  └────────────┴──────────────┴────────────────────┘     │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Component Relationships

```
┌──────────────┐      Uses      ┌──────────────┐
│   iOS App    │ ─────────────> │ Flask Backend│
└──────────────┘                └──────────────┘
       │                               │
       │ OAuth2                        │ API Calls
       ↓                               ↓
┌──────────────┐                ┌──────────────┐
│  Canvas LMS  │ <───────────── │ Canvas Client│
└──────────────┘   Fetch Data   └──────────────┘
                                       │
                                       │ Route Requests
                                       ↓
                          ┌────────────┴────────────┐
                          │                         │
                    ┌─────▼─────┐           ┌──────▼──────┐
                    │    GROQ   │           │ Perplexity  │
                    │    API    │           │     API     │
                    └───────────┘           └─────────────┘
                    (Math/Calc)             (Facts/Research)
```

---

## 2. Backend Architecture

### 2.1 Core Services

#### **2.1.1 Authentication Service** (`src/auth/auth_service.py`)

**Purpose**: Handles Canvas OAuth2 authentication and token management

**Key Components**:
- `CanvasAuthService`: Main auth coordinator
- `TokenManager`: Encrypts/decrypts access tokens
- `User` model: Stores user data

**Flow**:
```
User Login → OAuth2 Authorization → Token Exchange → Encrypted Storage → API Access
```

**Key Methods**:
- `get_authorization_url()`: Generates Canvas OAuth URL
- `exchange_code_for_token()`: Exchanges auth code for access token
- `refresh_token()`: Refreshes expired tokens
- `get_current_user()`: Retrieves authenticated user info

#### **2.1.2 Canvas API Client** (`src/canvas/canvas_client.py`)

**Purpose**: Wrapper for Canvas LMS REST API with rate limiting and caching

**Key Features**:
- Rate limit handling (remaining requests tracking)
- Response caching (30-minute TTL)
- Automatic pagination
- Error handling and retry logic

**Endpoints Wrapped**:
- Courses: `GET /api/v1/courses`
- Assignments: `GET /api/v1/courses/{id}/assignments`
- Submissions: `GET /api/v1/courses/{id}/assignments/{id}/submissions`
- Files: `GET /api/v1/courses/{id}/files`
- Quiz Questions: `GET /api/v1/courses/{id}/quizzes/{id}/questions`

#### **2.1.3 LLM Service** (`src/llm/llm_service.py`)

**Purpose**: Dual AI integration with intelligent routing

**Architecture**:
```
┌─────────────────────────────────────────────────┐
│            LLM Service Coordinator              │
├─────────────────────────────────────────────────┤
│                                                 │
│  Request Analysis                               │
│  ┌────────────────────────────────────┐         │
│  │ Request Type?                      │         │
│  │  - Calculate Math?  → GROQ         │         │
│  │  - Search Facts?    → Perplexity   │         │
│  │  - Explain Concept? → Perplexity   │         │
│  │  - Assignment Help? → Perplexity   │         │
│  └────────────────────────────────────┘         │
│                                                 │
│  ┌──────────────┐       ┌──────────────┐       │
│  │  GROQ        │       │ Perplexity   │       │
│  │  Adapter     │       │  Adapter     │       │
│  │  - Fast      │       │  - Sources   │       │
│  │  - Math      │       │  - Citations │       │
│  └──────────────┘       └──────────────┘       │
└─────────────────────────────────────────────────┘
```

**Key Methods**:
- `explain_concept()`: Educational explanations (Perplexity)
- `calculate_math()`: Mathematical computations (GROQ)
- `search_facts()`: Internet-backed research (Perplexity)
- `generate_assignment_help()`: Assignment assistance (Perplexity with RAG)
- `create_study_plan()`: Intelligent study scheduling

### 2.2 Specialized Services

#### **2.2.1 File Upload Service** (`src/canvas/file_upload_service.py`)

**Purpose**: Implements Canvas 3-step file upload process

**Process**:
```
Step 1: Notify Canvas
   ↓ (Get upload URL + params)
Step 2: Upload File Data
   ↓ (Upload to Canvas storage)
Step 3: Confirm Upload
   ↓ (Finalize file record)
File Available
```

**Methods**:
- `upload_file_to_course()`: Upload to course files
- `upload_file_to_user()`: Upload to user's personal files
- `upload_file_from_url()`: Import file from URL

#### **2.2.2 Assignment Submission Service** (`src/canvas/assignment_submission_service.py`)

**Purpose**: Handles all assignment submission types

**Submission Types**:
1. **Text Entry**: Direct HTML/text submission
2. **File Upload**: Attach files to assignment
3. **URL Submission**: Submit external links

**Methods**:
- `submit_text_entry()`: POST text to Canvas
- `submit_file_upload()`: Attach uploaded files
- `submit_url()`: Submit web link

#### **2.2.3 Study Plan Service** (`src/canvas/study_plan_service.py`)

**Purpose**: Generate intelligent study schedules with grade/syllabus integration

**Features**:
- Grade analysis per course
- Syllabus parsing
- Assignment prioritization
- Calendar event generation (.ics support)

**Data Sources**:
- Course grades
- Assignment due dates
- Course syllabi
- Performance history

#### **2.2.4 Formatting Service** (`src/formatting/formatting_service.py`)

**Purpose**: Format AI responses with tables, math, and citations

**Capabilities**:
- **Tables**: Convert data to Markdown tables
- **Math**: LaTeX rendering ($inline$, $$display$$)
- **Sources**: Formatted citations with clickable links
- **Structured Content**: Headers, lists, code blocks

**Input/Output**:
```
Raw AI Response (text)
   ↓
[Format Tables]
   ↓
[Format Math LaTeX]
   ↓
[Format Citations]
   ↓
Formatted Markdown with HTML-ready content
```

### 2.3 Data Models (`src/models/data_models.py`)

**Core Entities**:
- `Course`: Course information and metadata
- `Assignment`: Assignment details, due dates, submission types
- `Submission`: Student submissions and grading
- `Reminder`: Assignment reminders and notifications
- `File`: File metadata and storage info
- `User`: User profile and authentication

---

## 3. Frontend Architecture (iOS SwiftUI)

### 3.1 App Structure

```
CanvasAutomationFlowApp.swift (Entry Point)
   ↓
ContentView.swift (Tab Navigation)
   ↓
┌────────────┬──────────────┬──────────────┬─────────────┐
│ Dashboard  │   Courses    │ Assignments  │ AI Assistant│
└────────────┴──────────────┴──────────────┴─────────────┘
      ↓              ↓              ↓              ↓
┌────────────┬──────────────┬──────────────┬─────────────┐
│   Files    │  Reminders   │   More       │             │
└────────────┴──────────────┴──────────────┴─────────────┘
```

### 3.2 Core Components

#### **3.2.1 APIService.swift**

**Purpose**: Central API client and data management

**State Management**:
- `@Published var courses: [Course]`: All courses
- `@Published var coursesByTerm: [String: [Course]]`: Grouped courses
- `@Published var assignments: [Assignment]`: All assignments
- `@Published var reminders: [Reminder]`: User reminders
- `@Published var files: [File]`: Course files

**Key Methods**:
- Authentication: `signIn()`, `signOut()`
- Data Fetching: `fetchCourses()`, `fetchAssignments()`, `fetchFiles()`
- AI Operations: `getAssignmentHelp()`, `generateStudyPlan()`
- Submissions: `submitAssignmentText()`, `submitAssignmentFiles()`

#### **3.2.2 ThemeManager.swift**

**Purpose**: Dark futuristic theme management

**Features**:
- Custom color palette
- Monospaced fonts
- Glow effects
- Card styling

**Components**:
- `FuturisticFont`: Typography system
- `GlowingBorderModifier`: Animated borders
- `FuturisticCardModifier`: Card backgrounds
- `FuturisticButton`: Styled buttons

### 3.3 Feature Views

#### **3.3.1 DashboardView**

**Purpose**: Overview of courses and assignments

**Displays**:
- Course count
- Assignment statistics
- Due soon warnings
- Recent activity

#### **3.3.2 CoursesView**

**Purpose**: Browse and manage courses

**Features**:
- Grouped by academic term
- Status indicators
- Course details
- Refresh capability

**Structure**:
```
Search Bar (Filter courses)
   ↓
Term Sections
   ├─ Fall 2025
   │    ├─ Course 1
   │    ├─ Course 2
   │    └─ Course 3
   ├─ Spring 2025
   └─ Summer 2025
```

#### **3.3.3 AssignmentsView**

**Purpose**: Assignment tracking and management

**Features**:
- Filter by status (all, due soon, overdue)
- Swipe actions (AI help, reminders)
- Assignment detail navigation
- Search functionality

**Flow**:
```
Assignment List
   ↓ (Tap)
Assignment Detail
   ├─ HTML Description (scrollable)
   ├─ Due Date & Points
   ├─ Submission Types
   ├─ [Get AI Help]
   ├─ [Submit Text]
   ├─ [Submit Files]
   └─ [Submit URL]
```

#### **3.3.4 AIAssistantView**

**Purpose**: AI-powered academic assistance

**Features**:
- Assignment help with context files
- Concept explanation
- Study plan generation
- Math calculations
- Feedback drafting

**Capabilities**:
- File upload for context (RAG)
- Assignment auto-completion
- Source citations
- Document generation

#### **3.3.5 AssignmentSubmissionView**

**Purpose**: Multi-type assignment submission

**Submission Types**:
1. **Text Entry**: Rich text editor
2. **File Upload**: Device file picker
3. **URL Submission**: Link input

**UI Components**:
- TextEditor for online text entry
- File picker with preview
- URL validator
- Comment field
- Submit button

---

## 4. Key Data Flows

### 4.1 Authentication Flow

```
1. User taps "Sign In"
   ↓
2. App requests OAuth URL from backend
   ↓
3. Backend generates Canvas OAuth URL
   ↓
4. App opens WebView with OAuth URL
   ↓
5. User authorizes in Canvas
   ↓
6. Canvas redirects to callback with code
   ↓
7. Backend exchanges code for access token
   ↓
8. Backend encrypts and stores token
   ↓
9. Backend returns token to app
   ↓
10. App stores in Keychain
    ↓
11. App fetches user profile and courses
    ↓
12. Dashboard displayed
```

### 4.2 Assignment Submission Flow

```
1. User selects assignment
   ↓
2. Assignment detail loads (HTML rendered)
   ↓
3. User taps "Submit Text/Files/URL"
   ↓
4. Submission view opens
   ↓
5. User fills in content/selects files
   ↓
6. User adds optional comment
   ↓
7. User taps "Submit Assignment"
   ↓
8. App sends submission to backend
   ↓
9. Backend validates submission
   ↓
10. Backend calls Canvas API
    ↓
11. Canvas processes submission
    ↓
12. Success/failure returned
    ↓
13. UI shows feedback
    ↓
14. Modal dismisses on success
```

### 4.3 AI Assignment Help Flow (with RAG)

```
1. User selects assignment
   ↓
2. User taps "Get AI Help"
   ↓
3. AI Assistant modal opens
   ↓
4. User types question
   ↓
5. User uploads context files (optional)
   ↓
6. Files saved to temp storage
   ↓
7. Files uploaded to Canvas
   ↓
8. File metadata collected
   ↓
9. Request sent to backend with:
    - assignment_id
    - course_id
    - question
    - context_files[]
   ↓
10. Backend fetches assignment details
    ↓
11. Backend builds context:
     - Assignment description
     - Question
     - File contents/descriptions
    ↓
12. LLM Service routes to Perplexity
    ↓
13. Perplexity searches internet + context
    ↓
14. Response generated with sources
    ↓
15. Formatting Service formats response:
     - Tables
     - Math (LaTeX)
     - Citations (clickable links)
    ↓
16. Formatted response returned
    ↓
17. App displays with proper rendering
    ↓
18. User can copy, save, or submit
```

### 4.4 Study Plan Generation Flow

```
1. User selects courses
   ↓
2. User sets days ahead
   ↓
3. Request sent to backend
   ↓
4. Backend fetches:
    - Assignments (all courses)
    - Grades (per course)
    - Syllabus (per course)
   ↓
5. Study Plan Service analyzes:
    - Due dates
    - Performance (grades)
    - Workload distribution
   ↓
6. LLM generates intelligent plan
   ↓
7. Calendar events created
   ↓
8. Plan formatted with:
    - Daily schedule
    - Priority tasks
    - Time estimates
   ↓
9. .ics file generated (optional)
   ↓
10. Response returned to app
    ↓
11. Plan displayed with calendar export
```

---

## 5. Implementation Evolution

### 5.1 Initial System (SRS Phase)

**Features**:
- Basic Canvas authentication
- Course listing
- Assignment viewing
- Simple reminders
- Basic dashboard

**Architecture**:
- Simple Flask backend
- Basic SwiftUI views
- Canvas API integration
- OAuth2 authentication

### 5.2 Phase 2: AI Integration

**Additions**:
- GROQ integration for calculations
- Basic AI assistance
- Math rendering

**Changes**:
- LLM service added
- AI Assistant view created
- Math formatting service

### 5.3 Phase 3: Dual LLM Architecture

**Additions**:
- Perplexity integration
- Intelligent request routing
- Source citations
- Fact-based search

**Changes**:
- LLM adapter pattern
- Routing logic
- Response formatting

### 5.4 Phase 4: File Upload & RAG

**Additions**:
- Canvas file upload (3-step)
- RAG for AI context
- File management

**Changes**:
- File upload service
- Context integration
- AI help enhancement

### 5.5 Phase 5: Assignment Submission

**Additions**:
- Text submission
- File submission
- URL submission
- HTML rendering

**Changes**:
- Submission service
- Assignment detail view
- WebKit integration

### 5.6 Phase 6: Study Plan Enhancement

**Additions**:
- Grade integration
- Syllabus parsing
- Calendar export (.ics)
- Performance analysis

**Changes**:
- Study plan service
- Enhanced LLM prompts
- Calendar integration

### 5.7 Phase 7: UI/UX Overhaul

**Additions**:
- Dark futuristic theme
- Custom components
- Improved navigation
- Better error handling

**Changes**:
- Theme manager
- Custom modifiers
- Consistent styling
- Source citation UI

### 5.8 Current Phase: Quiz Support & Auto-Submission

**Planned Additions**:
- Quiz/exam integration
- Option-style questions
- Timed assessments
- AI auto-completion
- Document generation (PDF/LaTeX)
- Search functionality
- ChatGPT-like interface

---

## 6. Current Features (Implemented)

### 6.1 Authentication & Authorization
✅ Canvas OAuth2 integration  
✅ Token encryption and storage  
✅ Automatic token refresh  
✅ Secure API access  

### 6.2 Course Management
✅ Fetch all courses (with restrictions)  
✅ Group by academic term  
✅ Course details and descriptions  
✅ Status indicators  
✅ Consistency checking  

### 6.3 Assignment Management
✅ Fetch assignments from all courses  
✅ Filter by status  
✅ HTML description rendering  
✅ Due date tracking  
✅ Submission type identification  

### 6.4 AI Capabilities
✅ Dual LLM architecture (GROQ + Perplexity)  
✅ Intelligent request routing  
✅ Assignment help with context  
✅ Concept explanation  
✅ Math calculations  
✅ Study plan generation  
✅ Source citations  

### 6.5 File Management
✅ Canvas file upload (3-step process)  
✅ RAG context integration  
✅ File browsing  
✅ Multiple file formats  

### 6.6 Assignment Submission
✅ Text entry submission  
✅ File upload submission  
✅ URL submission  
✅ Comments on submissions  
✅ Success/failure feedback  

### 6.7 Study Planning
✅ Grade-aware planning  
✅ Syllabus integration  
✅ Assignment prioritization  
✅ Calendar event creation  

### 6.8 UI/UX
✅ Dark futuristic theme  
✅ Custom fonts and styling  
✅ Scrollable HTML rendering  
✅ Intuitive navigation  
✅ Error handling  

---

## 7. Upcoming Enhancements

### 7.1 Quiz/Exam Support

**Backend Changes**:
```python
# src/canvas/canvas_client.py
def get_quiz_with_questions(self, course_id: str, quiz_id: str) -> Dict:
    """Get quiz details including all questions"""
    quiz = self.get_quiz(course_id, quiz_id)
    questions = self.get_quiz_questions(course_id, quiz_id)
    
    return {
        'quiz': quiz,
        'questions': questions,
        'question_types': self._parse_question_types(questions)
    }

def _parse_question_types(self, questions: List[Dict]) -> Dict:
    """Categorize questions by type"""
    types = {
        'multiple_choice': [],
        'true_false': [],
        'essay': [],
        'fill_in_blank': [],
        'matching': []
    }
    
    for q in questions:
        q_type = q.get('question_type')
        if q_type in types:
            types[q_type].append(q)
    
    return types
```

**Frontend Changes**:
```swift
// QuizView.swift
struct QuizView: View {
    let quiz: Quiz
    @State private var answers: [String: Any] = [:]
    @State private var timeRemaining: Int
    
    var body: some View {
        VStack {
            // Timer for timed quizzes
            if quiz.timeLimit > 0 {
                TimerView(timeRemaining: $timeRemaining)
            }
            
            // Questions
            ForEach(quiz.questions) { question in
                QuestionView(
                    question: question,
                    answer: $answers[question.id]
                )
            }
            
            // Submit button
            Button("Submit Quiz") {
                submitQuiz()
            }
        }
    }
}

// QuestionView.swift
struct QuestionView: View {
    let question: QuizQuestion
    @Binding var answer: Any?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(question.text)
            
            switch question.type {
            case .multipleChoice:
                MultipleChoiceView(
                    options: question.options,
                    selected: $answer
                )
            case .trueFalse:
                TrueFalseView(selected: $answer)
            case .essay:
                TextEditor(text: Binding(
                    get: { answer as? String ?? "" },
                    set: { answer = $0 }
                ))
            // ... other types
            }
        }
    }
}
```

### 7.2 AI Auto-Completion & Document Generation

**Required Packages**:
- `reportlab` (Python PDF generation)
- `pypandoc` (Markdown → PDF/LaTeX)
- `python-docx` (Word document generation)

**Backend Service**:
```python
# src/llm/document_generation_service.py
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet
import pypandoc

class DocumentGenerationService:
    """Generate documents from AI responses"""
    
    def generate_pdf_from_text(self, content: str, filename: str) -> str:
        """Generate PDF from text content"""
        doc = SimpleDocTemplate(filename, pagesize=letter)
        styles = getSampleStyleSheet()
        story = []
        
        # Parse content and add to PDF
        for paragraph in content.split('\n\n'):
            story.append(Paragraph(paragraph, styles['Normal']))
            story.append(Spacer(1, 12))
        
        doc.build(story)
        return filename
    
    def generate_pdf_from_latex(self, latex_content: str, filename: str) -> str:
        """Convert LaTeX to PDF"""
        # Save LaTeX to temp file
        temp_tex = f"{filename}.tex"
        with open(temp_tex, 'w') as f:
            f.write(latex_content)
        
        # Convert using pandoc
        pypandoc.convert_file(temp_tex, 'pdf', outputfile=filename)
        return filename
    
    def auto_complete_assignment(
        self, 
        assignment: Assignment, 
        context_files: List[Any],
        user_instructions: str = ""
    ) -> Dict[str, Any]:
        """AI auto-completes assignment"""
        
        # Build comprehensive prompt
        prompt = f"""
Complete this assignment professionally:

**Assignment**: {assignment.name}
**Description**: {assignment.description}
**Points**: {assignment.points_possible}
**Type**: {', '.join(assignment.submission_types)}

**User Instructions**: {user_instructions or 'Complete to best of ability'}

**Context Files**: {len(context_files)} files provided

Requirements:
1. Answer all questions thoroughly
2. Use proper academic formatting
3. Cite sources appropriately
4. Follow submission guidelines
5. Ensure clarity and coherence

Generate complete submission content.
"""
        
        # Get AI response
        response = llm_service.generate_assignment_help(
            assignment,
            prompt,
            context_files
        )
        
        # Generate document if needed
        if 'online_upload' in assignment.submission_types:
            # Generate PDF
            pdf_file = self.generate_pdf_from_text(
                response.content,
                f"assignment_{assignment.id}.pdf"
            )
            return {
                'content': response.content,
                'document': pdf_file,
                'format': 'pdf',
                'sources': response.sources
            }
        else:
            return {
                'content': response.content,
                'sources': response.sources
            }
```

**Frontend Integration**:
```swift
// AIAssignmentCompletionView.swift
struct AIAssignmentCompletionView: View {
    let assignment: Assignment
    @State private var instructions = ""
    @State private var contextFiles: [File] = []
    @State private var isGenerating = false
    @State private var completion: AssignmentCompletion?
    @State private var showingConfirmation = false
    
    var body: some View {
        VStack {
            Text("AI Assignment Auto-Completion")
                .font(.headline)
            
            // Instructions
            TextField("Special instructions...", text: $instructions)
            
            // Context files
            FilePickerView(selectedFiles: $contextFiles)
            
            // Generate button
            Button("Generate Assignment") {
                Task {
                    await generateAssignment()
                }
            }
            .disabled(isGenerating)
            
            // Preview
            if let completion = completion {
                CompletionPreview(completion: completion)
                
                // Submit button
                Button("Review & Submit") {
                    showingConfirmation = true
                }
            }
        }
        .sheet(isPresented: $showingConfirmation) {
            SubmissionConfirmationView(
                completion: completion!,
                onConfirm: submitAssignment
            )
        }
    }
    
    private func generateAssignment() async {
        isGenerating = true
        completion = await apiService.autoCompleteAssignment(
            assignment: assignment,
            instructions: instructions,
            contextFiles: contextFiles
        )
        isGenerating = false
    }
    
    private func submitAssignment() {
        // Submit to Canvas
    }
}
```

### 7.3 Search Functionality

**Backend Endpoint**:
```python
@app.route('/api/search', methods=['GET'])
@require_auth
def search():
    """Universal search across courses and assignments"""
    query = request.args.get('q', '')
    entity_type = request.args.get('type', 'all')  # 'courses', 'assignments', 'all'
    
    client = CanvasAPIClient(
        base_url=os.getenv('CANVAS_BASE_URL'),
        access_token=g.canvas_token
    )
    
    results = {
        'courses': [],
        'assignments': []
    }
    
    if entity_type in ['courses', 'all']:
        courses = client.get_courses()
        results['courses'] = [
            c for c in courses
            if query.lower() in c.get('name', '').lower()
        ]
    
    if entity_type in ['assignments', 'all']:
        # Search across all courses
        all_assignments = []
        courses = client.get_courses()
        for course in courses:
            assignments = client.get_assignments(course['id'])
            all_assignments.extend(assignments)
        
        results['assignments'] = [
            a for a in all_assignments
            if query.lower() in a.get('name', '').lower()
            or query.lower() in a.get('description', '').lower()
        ]
    
    return jsonify(results)
```

**Frontend Implementation**:
```swift
// SearchBar.swift
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// Usage in CoursesView
struct CoursesView: View {
    @State private var searchText = ""
    
    var filteredCourses: [Course] {
        if searchText.isEmpty {
            return apiService.courses
        } else {
            return apiService.courses.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText, placeholder: "Search courses...")
                    .padding()
                
                List(filteredCourses) { course in
                    CourseRow(course: course)
                }
            }
        }
    }
}
```

### 7.4 ChatGPT-like Response Interface

**Requirements**:
- Markdown rendering with syntax highlighting
- LaTeX math rendering
- Clickable citations
- Code block formatting
- Table rendering

**Package**: `MarkdownUI` (Swift Package)

**Implementation**:
```swift
// Install via SPM: https://github.com/gonzalezreal/swift-markdown-ui

import MarkdownUI

// AIResponseView.swift
struct AIResponseView: View {
    let response: AIResponse
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Main content with markdown
                Markdown(response.content)
                    .markdownTheme(.gitHub)
                    .markdownCodeSyntaxHighlighter(.splash(theme: .sunset(withFont: .init(size: 16))))
                
                // Sources section
                if !response.sources.isEmpty {
                    Divider()
                    
                    Text("Sources")
                        .font(.headline)
                    
                    ForEach(response.sources.indices, id: \.self) { index in
                        SourceLinkView(
                            number: index + 1,
                            source: response.sources[index]
                        )
                    }
                }
            }
            .padding()
        }
    }
}

// SourceLinkView.swift
struct SourceLinkView: View {
    let number: Int
    let source: Source
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("[\(number)]")
                .font(.caption)
                .foregroundColor(.blue)
            
            if let url = URL(string: source.url) {
                Link(destination: url) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.title)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Text(source.url)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// Math rendering with LaTeX
extension Markdown {
    func renderLatex() -> some View {
        self.modifier(LaTeXModifier())
    }
}

struct LaTeXModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .markdownInlineImageProvider(.laTeX)
    }
}
```

### 7.5 Calendar Integration (.ics Export)

**Backend Implementation**:
```python
# src/calendar/calendar_service.py
from icalendar import Calendar, Event
from datetime import datetime, timedelta

class CalendarService:
    """Generate calendar events for study plans"""
    
    def create_ics_from_study_plan(
        self, 
        study_plan: Dict[str, Any],
        user_email: str
    ) -> str:
        """Generate .ics file from study plan"""
        
        cal = Calendar()
        cal.add('prodid', '-//Canvas Automation Flow//Study Plan//')
        cal.add('version', '2.0')
        cal.add('method', 'PUBLISH')
        
        # Add events for each task
        for task in study_plan.get('tasks', []):
            event = Event()
            event.add('summary', task['title'])
            event.add('description', task['description'])
            event.add('dtstart', task['start_time'])
            event.add('dtend', task['end_time'])
            event.add('location', 'Canvas LMS')
            event.add('status', 'CONFIRMED')
            event.add('uid', f"{task['id']}@canvasautomation.com")
            
            # Add alarm 1 hour before
            alarm = Alarm()
            alarm.add('trigger', timedelta(hours=-1))
            alarm.add('action', 'DISPLAY')
            alarm.add('description', f"Reminder: {task['title']}")
            event.add_component(alarm)
            
            cal.add_component(event)
        
        # Write to file
        filename = f"study_plan_{datetime.now().strftime('%Y%m%d')}.ics"
        with open(filename, 'wb') as f:
            f.write(cal.to_ical())
        
        return filename

# API endpoint
@app.route('/api/calendar/export', methods=['POST'])
@require_auth
def export_calendar():
    """Export study plan as .ics file"""
    data = request.get_json()
    study_plan = data.get('study_plan')
    
    calendar_service = CalendarService()
    ics_file = calendar_service.create_ics_from_study_plan(
        study_plan,
        g.user.email
    )
    
    return send_file(ics_file, as_attachment=True)
```

**Frontend Integration**:
```swift
// CalendarExportView.swift
struct CalendarExportView: View {
    let studyPlan: StudyPlan
    @State private var isExporting = false
    
    var body: some View {
        VStack {
            Button("Export to Calendar (.ics)") {
                exportCalendar()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func exportCalendar() {
        isExporting = true
        
        Task {
            let url = await apiService.exportStudyPlanToCalendar(studyPlan)
            
            if let url = url {
                // Share sheet to save/open .ics file
                let activityVC = UIActivityViewController(
                    activityItems: [url],
                    applicationActivities: nil
                )
                
                UIApplication.shared.windows.first?.rootViewController?
                    .present(activityVC, animated: true)
            }
            
            isExporting = false
        }
    }
}
```

---

## 8. Technical Stack

### Backend
- **Framework**: Flask 2.3+
- **Language**: Python 3.10+
- **AI**: GROQ API, Perplexity API
- **Canvas**: Canvas LMS REST API
- **Document Generation**: ReportLab, PyPandoc
- **Calendar**: iCalendar
- **Environment**: dotenv, cryptography

### Frontend
- **Framework**: SwiftUI
- **Language**: Swift 5.9+
- **Minimum iOS**: 17.0
- **Markdown**: MarkdownUI
- **Web Rendering**: WebKit
- **Networking**: URLSession

### Infrastructure
- **Authentication**: OAuth2
- **Storage**: iOS Keychain, encrypted tokens
- **Communication**: HTTPS/REST
- **Caching**: In-memory with TTL

---

## 9. Security & Reliability

### Security Measures
- OAuth2 token encryption (AES-256)
- HTTPS-only communication
- Secure keychain storage
- Environment variable protection
- Input validation and sanitization

### Reliability Features
- Rate limiting and backoff
- Response caching
- Error recovery
- Graceful degradation
- Background sync

### Performance
- Concurrent API requests
- Intelligent caching
- Background processing
- Lazy loading

---

## 10. Deployment Architecture

### Development
- Local Flask server (port 8000)
- iOS Simulator/Device
- Canvas test instance

### Staging
- Heroku/AWS deployment
- Production Canvas instance
- TestFlight distribution

### Production
- Load-balanced Flask servers
- CDN for static assets
- App Store distribution
- Monitoring and analytics

---

## Conclusion

The Canvas Automation Flow system has evolved into a comprehensive academic assistant with AI-powered features, seamless Canvas integration, and intelligent automation. The upcoming enhancements will further solidify its position as an essential tool for students.

**Next Steps**:
1. Implement quiz/exam support
2. Build AI auto-completion with document generation
3. Add search functionality
4. Create ChatGPT-like response interface
5. Integrate calendar export
6. Comprehensive testing
7. Production deployment

---

**Document Version**: 1.0  
**Last Updated**: October 1, 2025  
**Author**: Canvas Automation Flow Development Team

