# Prompt for Claude: Generate Comprehensive Flow Diagrams for Canvas Automation Flow

## Context

You are tasked with creating detailed, professional flow diagrams for the **Canvas Automation Flow** system - an educational technology solution that combines a Python Flask backend with an iOS SwiftUI frontend, featuring AI-powered academic assistance through dual LLM integration (GROQ for calculations, Perplexity for factual research with citations).

The system has successfully evolved from a basic Canvas LMS integration to a sophisticated platform capable of:
- Authenticating via Canvas OAuth2
- Fetching and managing courses/assignments
- Providing AI-powered assignment help with context files (RAG)
- Submitting assignments directly to Canvas (text, files, URLs)
- Generating intelligent study plans with grade integration
- Rendering mathematical expressions and formatting AI responses
- **Successfully posting completed assignments to Canvas**

---

## Diagrams Required

Please create the following diagrams using standard flowchart/architecture diagram conventions (boxes, arrows, decision diamonds, swim lanes where appropriate):

### 1. **System Architecture Overview**
Create a high-level architecture diagram showing:

**Components to Include**:
- iOS Client (SwiftUI)
  - Main Views: Dashboard, Courses, Assignments, AI Assistant, Files, Reminders, More
  - APIService layer
  - ThemeManager
  
- Python Flask Backend
  - API Layer (Flask routes)
  - Service Layer (LLM, Canvas, Sync, Notification, File Upload, Assignment Submission, Study Plan, Formatting)
  - Data Models
  
- External Integrations
  - Canvas LMS API
  - GROQ API (for calculations)
  - Perplexity API (for factual search with citations)

**Show**:
- Communication protocols (HTTPS/REST)
- Data flow directions
- Authentication flow (OAuth2)
- Component relationships

---

### 2. **Backend Service Architecture**
Create a detailed backend architecture showing:

**Layers** (use horizontal swim lanes):
1. **API Layer**: Flask routes and endpoints
2. **Service Layer**: Core business logic services
3. **Integration Layer**: External API clients
4. **Data Layer**: Models and database interface

**Services to Detail**:
- Authentication Service (OAuth2, Token Management)
- Canvas API Client (rate limiting, caching)
- LLM Service with dual adapter pattern (GROQ + Perplexity)
- File Upload Service (3-step Canvas upload)
- Assignment Submission Service (text/file/URL)
- Study Plan Service (grade/syllabus integration)
- Formatting Service (tables, math, citations)

**Show Interactions Between Services**

---

### 3. **LLM Service Architecture - Dual API Routing**
Create a detailed flowchart showing the intelligent routing logic:

**Flow**:
1. Request arrives at LLM Service
2. Request analysis/classification
3. Routing decision:
   - Calculate Math? → GROQ Adapter
   - Search Facts? → Perplexity Adapter
   - Explain Concept? → Perplexity Adapter
   - Assignment Help? → Perplexity Adapter (with RAG)
   - Study Plan? → GROQ/Perplexity hybrid
4. Adapter processes request
5. Response formatting
6. Return formatted response with sources (if Perplexity)

**Include**:
- Decision diamonds for routing logic
- Adapter components
- Response formatting pipeline
- Error handling paths

---

### 4. **Authentication Flow (OAuth2)**
Create a sequence diagram or detailed flowchart showing:

**Steps**:
1. User taps "Sign In" in iOS app
2. App requests OAuth URL from backend
3. Backend generates Canvas OAuth authorization URL
4. App opens WebView with OAuth URL
5. User authorizes in Canvas
6. Canvas redirects to callback with authorization code
7. Backend exchanges code for access token
8. Backend encrypts token and stores
9. Backend returns encrypted token to app
10. App stores token in iOS Keychain
11. App makes authenticated API call
12. Backend validates token
13. Backend decrypts token
14. Backend calls Canvas API with token
15. Data returned through chain

**Show**:
- iOS App, Backend, Canvas LMS as separate swim lanes
- Secure storage points
- Token encryption/decryption steps

---

### 5. **Assignment Submission Flow**
Create a comprehensive flowchart showing:

**Main Flow**:
1. User selects assignment
2. Assignment details loaded (HTML rendered)
3. User chooses submission type (text/file/URL)
4. Submission view opens
5. User fills content/selects files/enters URL
6. User adds optional comment
7. User taps "Submit Assignment"
8. App validates input
9. Request sent to backend
10. Backend validates submission
11. Backend calls Canvas API submission endpoint
12. Canvas processes and confirms submission
13. Success response propagated back
14. UI updated with confirmation
15. Modal dismisses

**Include**:
- Decision diamonds for validation
- Error handling branches
- Success/failure paths
- File upload sub-flow for file submissions

---

### 6. **AI Assignment Help Flow with RAG**
Create a detailed sequence diagram showing:

**Participants**:
- User (iOS App)
- Backend API
- Canvas API
- File Upload Service
- LLM Service
- Perplexity API
- Formatting Service

**Flow**:
1. User selects assignment
2. User taps "Get AI Help"
3. AI modal opens
4. User types question
5. User uploads context files (optional)
6. Files saved to temp storage
7. Files uploaded to Canvas via 3-step process
8. File metadata collected
9. Request sent to backend with assignment_id, course_id, question, context_files
10. Backend fetches assignment details from Canvas
11. Backend builds comprehensive context (assignment + question + files)
12. LLM Service routes to Perplexity
13. Perplexity searches internet + analyzes context
14. Response generated with sources/citations
15. Formatting Service processes response (tables, math LaTeX, clickable citations)
16. Formatted response returned to app
17. App renders with ChatGPT-like interface
18. User can copy, save, or submit as assignment

**Show**:
- Context building process
- RAG integration
- Source extraction
- Formatting pipeline

---

### 7. **Study Plan Generation Flow**
Create a flowchart showing:

**Steps**:
1. User selects courses
2. User sets "days ahead" parameter
3. Request sent to backend
4. Backend fetches:
   - Assignments from selected courses
   - Grades per course (handle 403 gracefully)
   - Syllabus per course (handle 403 gracefully)
5. Study Plan Service analyzes:
   - Due dates and urgency
   - Performance (grades) for prioritization
   - Workload distribution
   - Course difficulty
6. LLM generates intelligent study schedule
7. Calendar events created
8. Plan formatted with:
   - Daily schedule
   - Priority tasks
   - Time estimates
   - Study strategies
9. Optional: .ics file generated
10. Response returned to app
11. Plan displayed with calendar export option

**Include**:
- Data aggregation from multiple sources
- Analysis algorithms
- LLM prompt engineering
- Calendar export branch

---

### 8. **File Upload Service (3-Step Canvas Process)**
Create a detailed flowchart showing:

**Steps**:
1. Client initiates file upload
2. **Step 1**: Notify Canvas
   - POST to `/api/v1/courses/{id}/files` with file metadata
   - Canvas returns upload URL and params
3. **Step 2**: Upload file data
   - POST file data to upload URL with params
   - Canvas stores file
4. **Step 3**: Confirm upload
   - POST to confirm endpoint
   - Canvas finalizes file record
5. File available in Canvas

**Show**:
- Each step clearly
- Data exchanged at each step
- Error handling
- Success confirmation

---

### 9. **Frontend Navigation Flow**
Create a state diagram or flowchart showing:

**Views**:
- Authentication View
- Dashboard View
- Courses View → Course Detail (future)
- Assignments View → Assignment Detail → Submission View
- AI Assistant View
- Files View
- Reminders View
- More/Settings View

**Navigation Patterns**:
- Tab-based navigation
- Modal presentations
- Navigation stack pushes
- Dismissals

**Show**:
- Entry points
- Transitions
- Modals
- Navigation hierarchy

---

### 10. **Data Synchronization Flow**
Create a flowchart showing:

**Background Sync Process**:
1. Sync service starts (background thread)
2. Check last sync timestamp
3. If interval elapsed, trigger sync
4. Sync courses
5. For each course, sync assignments
6. Sync user files
7. Sync reminders
8. Update cache timestamps
9. Sleep until next interval

**Pull-to-Refresh**:
1. User pulls to refresh
2. Force sync triggered
3. UI shows loading indicator
4. Sync completes
5. UI updates
6. Loading indicator dismissed

**Show**:
- Background vs. foreground sync
- Cache invalidation
- Concurrent operations
- Rate limiting

---

### 11. **Error Handling & Recovery Architecture**
Create a flowchart showing:

**Error Types**:
- Network errors (timeout, no connection)
- Authentication errors (401, expired token)
- Authorization errors (403, restricted access)
- Canvas API errors (404, 500)
- LLM API errors (rate limit, timeout)
- Validation errors

**Recovery Strategies**:
- Retry with exponential backoff
- Token refresh
- Graceful degradation
- User notification
- Fallback options

**Show**:
- Error detection
- Recovery decision trees
- User feedback mechanisms

---

### 12. **Quiz/Exam Support Architecture (Planned Feature)**
Create a preliminary design diagram showing:

**Components**:
- Quiz fetch service
- Question type parser (multiple choice, true/false, essay, etc.)
- Timer component (for timed exams)
- Answer tracking
- Quiz submission service
- AI quiz assistance (with ethical considerations)

**Flow**:
1. Fetch quiz with questions
2. Parse question types
3. Display appropriate UI for each type
4. Track answers
5. Handle timer (if timed)
6. Submit quiz
7. Show results

---

### 13. **AI Auto-Completion with Document Generation (Planned Feature)**
Create a flowchart showing:

**Components**:
- Document Generation Service
- PDF generator (ReportLab/PyPandoc)
- LaTeX converter
- Word document generator

**Flow**:
1. User requests AI auto-completion
2. User provides instructions and context files
3. AI analyzes assignment requirements
4. AI generates complete response
5. System determines document format (based on submission type)
6. Document generated (PDF/LaTeX/Word)
7. Preview shown to user
8. User reviews and approves
9. Document submitted to Canvas
10. Confirmation displayed

---

## Diagram Requirements

### Visual Standards:
- Use standard flowchart symbols:
  - **Rectangles**: Processes/actions
  - **Diamonds**: Decisions/branching
  - **Parallelograms**: Input/output
  - **Cylinders**: Databases/storage
  - **Clouds**: External services
  - **Rounded rectangles**: Start/end points
  
- **Colors** (optional but helpful):
  - Blue: iOS/frontend components
  - Green: Backend services
  - Orange: External integrations (Canvas, LLM APIs)
  - Red: Error paths
  - Purple: AI/ML components

- **Swim Lanes**: Use for multi-actor flows (authentication, submissions)

- **Annotations**: Add brief labels/notes for clarity

- **Legend**: Include a legend if using colors or special symbols

### Format:
- Create diagrams suitable for:
  - Academic presentation
  - Technical documentation
  - Stakeholder review
  - Development team reference

- Ensure diagrams are:
  - Clear and readable
  - Properly labeled
  - Logically organized
  - Consistent in style

---

## System Evolution Timeline

Include a timeline diagram showing major phases:

1. **Phase 1 (SRS)**: Basic Canvas integration, OAuth2, course/assignment viewing
2. **Phase 2**: GROQ integration, basic AI assistance
3. **Phase 3**: Perplexity integration, dual LLM routing, source citations
4. **Phase 4**: File upload (3-step), RAG integration
5. **Phase 5**: Assignment submission (text/file/URL), HTML rendering
6. **Phase 6**: Study plan enhancement, grade integration, calendar export
7. **Phase 7**: UI/UX overhaul, dark theme, improved formatting
8. **Phase 8 (Current)**: Quiz support, AI auto-completion, search, ChatGPT-like interface

**Show**:
- Major features added each phase
- Technology integrations
- Architectural changes

---

## Key Achievements to Highlight

- ✅ Successfully authenticates via Canvas OAuth2
- ✅ Fetches all courses (23 courses across 4 terms)
- ✅ Retrieves assignments from all accessible courses
- ✅ Provides AI help with context files using RAG
- ✅ **Successfully submits assignments to Canvas** (verified working)
- ✅ Generates study plans with grade/syllabus integration
- ✅ Formats responses with tables, LaTeX math, and clickable citations
- ✅ Handles Canvas API restrictions gracefully (403 errors)
- ✅ Dual LLM architecture working (GROQ + Perplexity)

---

## Technical Details for Accuracy

### Backend:
- **Language**: Python 3.10+
- **Framework**: Flask 2.3+
- **AI APIs**: GROQ (calculations), Perplexity (facts with online search)
- **Authentication**: OAuth2 with encrypted token storage
- **Canvas API**: REST API v1
- **File Upload**: 3-step process (notify → upload → confirm)

### Frontend:
- **Language**: Swift 5.9+
- **Framework**: SwiftUI
- **Min iOS**: 17.0
- **Networking**: URLSession with async/await
- **Storage**: iOS Keychain for tokens
- **Rendering**: WebKit for HTML, planned MarkdownUI for AI responses

### Infrastructure:
- **Protocol**: HTTPS/REST
- **Port**: 8000 (development)
- **Deployment**: Flask development server (moving to production WSGI)

---

## Final Notes

These diagrams will be used for:
1. **Academic Report**: Midterm project documentation
2. **Technical Documentation**: Developer onboarding
3. **Stakeholder Presentation**: Feature demonstration
4. **System Design**: Architecture reference

Please create professional, accurate diagrams that clearly communicate the system's complexity, sophistication, and successful implementation. The diagrams should showcase both the current state and planned enhancements.

**Emphasis**: Highlight the successful integration of AI capabilities, the working assignment submission feature, and the dual LLM architecture as key differentiators from basic Canvas integrations.

Thank you!

