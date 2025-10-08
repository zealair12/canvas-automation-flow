# AI Help Debugging Guide

## 🐛 Issues Fixed

### Screenshot 1: AI Assistant (Assignment Help)
**Problem:** User gets "Sorry, I couldn't generate a response" when clicking "Generate with AI"

**Root Cause:** No assignment was selected, causing empty strings to be sent to backend
- iOS sent: `assignmentId: ""` and `courseId: ""`
- Backend returned: `400 Bad Request - "Assignment ID is required"`
- iOS showed: Generic error message

**Fix:**
```swift
// Before:
let helpResult = await apiService.getAssignmentHelpWithFiles(
    assignmentId: selectedAssignment?.canvasAssignmentId ?? "",  // ❌ Empty string!
    courseId: selectedAssignment?.courseId ?? "",                // ❌ Empty string!
    ...
)

// After:
guard let assignment = selectedAssignment else {
    aiResponse = "Please select an assignment first."  // ✅ Helpful message
    return
}
let helpResult = await apiService.getAssignmentHelpWithFiles(
    assignmentId: assignment.canvasAssignmentId,     // ✅ Valid ID
    courseId: assignment.courseId,                    // ✅ Valid ID
    ...
)
```

### Screenshot 2: AI Help (Assignment Detail Modal)
**Problem:** User gets "Sorry, I couldn't get help for this assignment"

**Root Causes:**
1. Empty question sent to backend
2. Network error
3. Assignment not found in Canvas
4. LLM service not configured
5. Backend error not being shown

**Fix:**
```swift
// Added validation
guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
    response = "Please enter your question first."
    return
}

// Added debug logging
print("🔍 Getting AI help for assignment: \(assignment.canvasAssignmentId)")
print("📋 Course: \(assignment.courseId)")
print("❓ Question: \(fullQuestion)")
print("🎯 Help Type: \(helpTypeParam)")

// Improved error message
if let result = helpResponse {
    print("✅ Received AI response")
    response = result.content
} else {
    print("❌ Failed to get AI response")
    response = "Unable to get AI help. Please check:\n" +
              "• Network connection\n" +
              "• Assignment: \(assignment.name)\n" +
              "• Course ID: \(assignment.courseId)\n" +
              "• Backend server is running\n" +
              "• LLM service is configured\n\n" +
              "Try again or check logs."
}
```

### Screenshot 3: AI Assignment Help (Swipe Action)
**Problem:** Similar to Screenshot 2

**Fix:** Same improvements as Screenshot 2

---

## 🔍 How to Debug AI Help Issues

### 1. Check iOS Console Logs
When AI help fails, look for these logs in Xcode console:

```
🔍 Getting AI help for assignment: 12345 in course: 67890
📝 Question: Can you answer each question?
✅ Received AI response  ← Success!
```

or

```
🔍 Getting AI help for assignment: 12345 in course: 67890
📝 Question: Can you answer each question?
❌ Failed to get AI response  ← Failure!
```

### 2. Check Backend Logs
Backend logs will show:

**Success:**
```
INFO - Getting AI help for assignment 12345
INFO - Assignment found: Chemical Safety Quiz
INFO - Using Perplexity for research help
INFO - Generated response: 438 characters
```

**Failure:**
```
ERROR - Missing assignment_id in request data: {}
ERROR - Assignment ID is required
```

or

```
ERROR - Canvas API error for assignment 12345: Resource not found
ERROR - Assignment not found
```

### 3. Common Issues and Solutions

#### Issue: "Please select an assignment first"
**Cause:** No assignment selected in AI Assistant
**Solution:** Select an assignment from the dropdown before clicking "Generate with AI"

#### Issue: "Please enter your question"
**Cause:** Question field is empty
**Solution:** Type your question in the text field

#### Issue: "Unable to get AI help. Please check: ..."
**Causes:**
1. **Network connection** - Check Wi-Fi/cellular
2. **Assignment not found** - Assignment might have been deleted from Canvas
3. **Backend not running** - Start backend: `python src/main.py`
4. **LLM service not configured** - Check `.env` for GROQ_API_KEY and PERPLEXITY_API_KEY

#### Issue: Backend returns 400
**Cause:** Invalid request data
**Check:**
- Assignment ID is not empty
- Course ID is not empty
- Question is not empty

#### Issue: Backend returns 404
**Cause:** Assignment not found in Canvas
**Solution:** 
- Verify assignment exists in Canvas
- Refresh assignments list
- Check assignment ID is correct

#### Issue: Backend returns 500
**Cause:** Server error (LLM service, Canvas API, etc.)
**Check backend logs for:**
- `ModuleNotFoundError` - Missing Python dependencies
- `Canvas API error` - Canvas API issue
- `LLM service error` - Groq/Perplexity API issue

---

## 🛠 Testing Checklist

After making changes, test these scenarios:

### AI Assistant (Screenshot 1):
- [ ] Click "Generate" without selecting assignment → Shows "Please select an assignment first"
- [ ] Select assignment but leave question empty → Shows "Please enter your question"
- [ ] Select assignment and enter question → Gets AI response
- [ ] Upload context files → AI uses file context
- [ ] Check logs for debug output

### Assignment Detail AI Help (Screenshot 2):
- [ ] Click "Get AI Help" with empty question → Shows "Please enter your question first"
- [ ] Enter question and click "Get AI Help" → Gets AI response
- [ ] Select different help types (Analysis, Guidance, Research, Solution)
- [ ] Add context files → AI uses file context
- [ ] Check logs show assignment context

### Swipe Action AI Help (Screenshot 3):
- [ ] Swipe assignment and tap "AI Help"
- [ ] Enter question in modal
- [ ] Click "Get AI Help" → Gets AI response
- [ ] Check logs show correct assignment ID

---

## 📊 API Flow

### Successful Request:
```
iOS App
  ↓
1. User selects assignment: "Chemical Safety Quiz" (ID: 12345)
2. User enters question: "Can you explain the key concepts?"
3. User clicks "Get AI Help"
  ↓
API Call
  ↓
Backend /api/ai/assignment-help
  ↓
4. Validates assignment_id exists: ✅
5. Validates course_id exists: ✅
6. Fetches assignment from Canvas API: ✅
7. Builds context-aware prompt
8. Calls LLM (Groq/Perplexity): ✅
  ↓
Response
  ↓
9. Returns AI response with sources
  ↓
iOS App
  ↓
10. Displays response in MarkdownView ✅
```

### Failed Request (Fixed):
```
iOS App
  ↓
1. User forgets to select assignment
2. User clicks "Generate with AI"
  ↓
OLD BEHAVIOR:
  ↓
3. iOS sends: assignmentId: "", courseId: ""
4. Backend returns: 400 "Assignment ID is required"
5. iOS shows: "Sorry, couldn't generate response" ❌

NEW BEHAVIOR:
  ↓
3. iOS validates: assignment == nil
4. iOS shows immediately: "Please select an assignment first" ✅
5. Prevents unnecessary API call
```

---

## 🎯 Validation Rules

### AI Assistant:
- **Assignment Help**: Requires assignment + question
- **Study Plan**: Requires ≥1 course
- **Concept Explainer**: Requires concept text
- **Feedback Draft**: Requires assignment + submission content

### Assignment Detail AI Help:
- Requires: question (assignment context automatic)
- Optional: context files
- Optional: help type selection

### Swipe Action AI Help:
- Requires: question (assignment context automatic)
- Always uses "guidance" help type

---

## 🔧 Code Locations

### AIAssistantView.swift
- Lines 326-408: `generateAIResponse()` function
- Lines 334-361: Assignment Help validation
- Lines 362-373: Study Plan validation
- Lines 374-385: Concept Explainer validation
- Lines 386-403: Feedback Draft validation

### AssignmentsView.swift
- Lines 400-431: `getAIHelp()` function
- Lines 404-407: Question validation
- Lines 412-413: Debug logging
- Lines 426-427: Improved error message

### AssignmentDetailView.swift
- Lines 370-414: `getAIHelp()` function
- Lines 372-375: Question validation
- Lines 386-390: Debug logging
- Lines 409-410: Detailed error message with context

---

## ✅ Result

**Before:** 
- Generic error messages
- No validation
- Silent failures
- No debugging info

**After:**
- Specific validation messages
- Pre-flight checks
- Detailed error messages with troubleshooting steps
- Comprehensive debug logging
- Assignment context kept in responses

**User Experience:**
- Clear guidance on what went wrong
- Actionable steps to fix issues
- Faster debugging with logs
- Better error messages for support
