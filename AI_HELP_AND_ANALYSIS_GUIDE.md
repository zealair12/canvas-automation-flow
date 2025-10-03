# AI Help & Analysis System - Complete Guide

## Overview

The Canvas Automation Flow now features a **fully functional AI Help & Analysis system** for every assignment, with:
- ✅ **4 specialized help types** (Analysis, Guidance, Research, Solution)
- ✅ **Context-aware prompts** based on assignment and course data
- ✅ **Multiple entry points** with different behaviors
- ✅ **Proper source citations** with clickable links
- ✅ **Beautiful rendering** with Markdown, LaTeX, and syntax highlighting

## Entry Points

### 1. Assignment Detail View → "AI Help & Analysis" Button

**Location:** When you tap on any assignment in the list  
**Features:**
- Full screen AI Help interface
- 4 help type options: **Analysis**, **Guidance**, **Research**, **Solution**
- File upload support for context
- Copy response button
- Beautiful MarkdownView with citations

**Help Types:**

| Type | Purpose | AI Service | Max Results |
|------|---------|------------|-------------|
| **Analysis** | Detailed breakdown of requirements | Perplexity | 5 sources |
| **Guidance** | Step-by-step how-to approach | Groq | None |
| **Research** | Factual information with sources | Perplexity | 10 sources |
| **Solution** | Complete solution development | Perplexity | 10 sources |

**How it works:**
```swift
Button: "AI Help & Analysis"
  ↓
Opens AssignmentAIHelpView
  ↓
Student selects help type (Analysis/Guidance/Research/Solution)
  ↓
Student types question
  ↓
Can optionally upload context files
  ↓
Backend uses specialized prompt for that help type
  ↓
Response displayed with MarkdownView (includes citations if available)
```

### 2. Assignment List → Swipe "AI Help"

**Location:** Swipe left on any assignment in the Assignments list  
**Features:**
- Quick help without opening full assignment details
- Uses "Guidance" help type by default
- Simplified interface for fast answers
- Still includes full Markdown rendering

**How it works:**
```swift
Swipe left on assignment → Tap "AI Help"
  ↓
Quick sheet opens with question input
  ↓
Student types question
  ↓
Backend uses "guidance" help type
  ↓
Response displayed with MarkdownView
```

## Backend Architecture

### API Endpoint: `/api/ai/assignment-help`

**Request:**
```json
{
  "assignment_id": "12345",
  "course_id": "67890",
  "question": "Help me understand this discussion prompt",
  "help_type": "analysis"  // Optional, defaults to "guidance"
}
```

**Response:**
```json
{
  "assignment": {
    "id": "assignment_12345",
    "name": "Introductions Discussion Board",
    "description": "...",
    ...
  },
  "help": "Markdown formatted response with **bold**, *italic*, $math$, etc.",
  "model": "sonar" or "llama3-70b-8192",
  "sources": [
    {
      "id": "1",
      "title": "Source Title",
      "url": "https://example.com",
      "snippet": "Relevant excerpt..."
    }
  ]
}
```

### Help Type Processing

The backend automatically enhances prompts based on help type:

**Analysis:**
```
"Provide a detailed analysis of the assignment requirements, 
breaking down what's being asked and what approach should be taken.

Student Question: [their question]"
```

**Guidance:**
```
"Provide step-by-step guidance on how to approach this assignment, 
including strategies and tips.

Student Question: [their question]"
```

**Research:**
```
"Conduct research and provide relevant information, examples, 
and sources to help with this assignment.

Student Question: [their question]"
```

**Solution:**
```
"Help develop a complete solution or response for this 
assignment with detailed explanations.

Student Question: [their question]"
```

### AI Service Selection

```python
if help_type in ['research', 'solution'] and llm_service.perplexity_adapter:
    # Use Perplexity with 10 sources for research-intensive help
    response = perplexity_adapter.search_facts(prompt, max_results=10)
    
elif help_type == 'analysis' and llm_service.perplexity_adapter:
    # Use Perplexity with 5 sources for factual analysis
    response = perplexity_adapter.search_facts(prompt, max_results=5)
    
else:
    # Use Groq for quick guidance
    response = groq_adapter.make_request(messages, temperature=0.5)
```

## Context Integration

### Automatic Context Gathering

For every help request, the system automatically fetches:

1. **Assignment Details:**
   - Name and description
   - Due date and points
   - Submission types
   - Grading rubric (if available)

2. **Course Context:**
   - Course name (e.g., "Discrete Mathematics")
   - Course code (e.g., "MATH 250")
   - Subject area

3. **Student Context:**
   - Academic level (undergraduate/graduate)
   - Previous grades (if available)
   - Course materials

```python
prompt_context = PromptContext(
    course_name="Discrete Mathematics",
    course_subject="MATH 250",
    assignment_type="discussion_post",
    due_date="2025-10-05T23:59:59Z",
    points_possible=10.0,
    student_level="undergraduate"
)
```

### Assignment Type Detection

The system detects assignment types from names and descriptions:

| Keywords | Detected Type | Specialized Prompt |
|----------|---------------|-------------------|
| "discussion", "forum", "post" | Discussion Board | Emphasizes thoughtful engagement |
| "problem", "exercise", "calculate" | Problem Set | Step-by-step problem solving |
| "essay", "paper", "write" | Essay | Thesis development and structure |
| "research", "investigate", "analyze" | Research | Source-based analysis |

Example:
```
Assignment Name: "Introductions Discussion Board"
→ Detected: Discussion Board
→ Uses discussion-specific prompt template
→ Emphasizes peer engagement and scholarly tone
```

## UI Features

### MarkdownView with Citations

The response is displayed using `MarkdownView.swift`, which provides:

1. **Markdown Rendering:**
   - Headers: `# ## ###`
   - Bold: `**text**`
   - Italic: `*text*`
   - Lists: `-` and `1.`
   - Code blocks: ` ```python ``` `
   - Inline code: `` `code` ``

2. **LaTeX Math:**
   - Inline: `$E=mc^2$`
   - Display: `$$\int_{-\infty}^{\infty} e^{-x^2} dx$$`
   - Symbols: `$\alpha$`, `$\beta$`, `$\sum$`, `$\int$`

3. **Clickable Citations:**
   - Citations appear as `[1]`, `[2]` in text
   - Clicking scrolls to source details at bottom
   - Source cards show:
     - Title (clickable link)
     - URL domain
     - Snippet preview
     - External link icon

4. **Responsive Design:**
   - Auto-adjusts height to content
   - Smooth scrolling
   - Dark mode support
   - Mobile-optimized

### Help Type Selector

```swift
Picker("Help Type", selection: $selectedHelpType) {
    Text("Analysis").tag(AIHelpType.analysis)
    Text("Guidance").tag(AIHelpType.guidance)
    Text("Research").tag(AIHelpType.research)
    Text("Solution").tag(AIHelpType.solution)
}
.pickerStyle(SegmentedPickerStyle())
```

This allows students to choose the type of help they need!

## Example Usage

### Scenario 1: Discussion Board Help

**Assignment:** "Introductions Discussion Board"  
**Student Action:** Tap assignment → "AI Help & Analysis"  
**Student Selects:** "Analysis"  
**Student Asks:** "What should I include in my introduction?"

**System Does:**
1. Detects "discussion" from assignment name
2. Fetches course context (Discrete Mathematics)
3. Uses Discussion Board specialized prompt
4. Adds Analysis enhancement
5. Uses Perplexity for factual info (5 sources)

**Response Includes:**
- Breakdown of discussion requirements
- Expected components of introduction
- Tips for academic tone
- Examples of good introductions
- Sources about effective academic discussions

### Scenario 2: Quick Problem Help

**Assignment:** "Homework 3: Logic Problems"  
**Student Action:** Swipe left on assignment → "AI Help"  
**Student Asks:** "How do I approach problem 5?"

**System Does:**
1. Detects "problem" from assignment name
2. Uses "guidance" help type (from swipe action)
3. Uses Problem-Solving specialized prompt
4. Uses Groq for quick response

**Response Includes:**
- Step-by-step approach
- Relevant formulas
- LaTeX-formatted equations
- Verification tips

### Scenario 3: Research Assignment

**Assignment:** "Research Paper on Cryptography"  
**Student Action:** Tap assignment → "AI Help & Analysis"  
**Student Selects:** "Research"  
**Student Asks:** "What are the latest developments in quantum-resistant cryptography?"

**System Does:**
1. Detects "research" from assignment name
2. Uses Research specialized prompt
3. Uses Perplexity with 10 sources

**Response Includes:**
- Overview of quantum-resistant cryptography
- Recent developments with dates
- Key algorithms and approaches
- 10 clickable citations to research papers
- Formatted with headers, lists, and emphasis

## Testing

### Test Analysis Help

1. Open any assignment
2. Tap "AI Help & Analysis"
3. Select "Analysis" from segmented control
4. Enter question: "Break down this assignment for me"
5. Tap "Get AI Help"
6. Verify:
   - Response uses Perplexity (if available)
   - Includes 5 sources at bottom
   - Citations are clickable
   - Markdown is properly formatted

### Test Swipe Quick Help

1. Go to Assignments list
2. Swipe left on any assignment
3. Tap "AI Help" (purple button)
4. Enter question: "How do I start this assignment?"
5. Tap "Get AI Help"
6. Verify:
   - Quick help sheet opens
   - Response appears
   - Markdown is formatted
   - Can copy response

### Test Different Help Types

For the same assignment, test all 4 help types with the same question:

**Question:** "Help me with this assignment"

**Analysis** should give:
- Breakdown of requirements
- What's being asked
- Approach strategy

**Guidance** should give:
- Step-by-step instructions
- Tips and strategies
- How to proceed

**Research** should give:
- Factual information
- 10 sources
- Examples and evidence

**Solution** should give:
- Complete response
- Detailed explanations
- Ready-to-use content

## API Service Updates

### Updated Function Signatures

```swift
// In APIService.swift

func getAssignmentHelp(
    assignmentId: String, 
    courseId: String, 
    question: String, 
    helpType: String = "guidance"
) async -> (content: String, sources: [[String: String]]?)?

func getAssignmentHelpWithFiles(
    assignmentId: String,
    courseId: String,
    question: String,
    files: [File],
    helpType: String = "guidance"
) async -> (content: String, sources: [[String: String]]?)?
```

**Changes:**
- Added `helpType` parameter with default
- Changed return type to tuple `(content, sources)`
- Sources can be `nil` if using Groq or no sources found

### Handling Sources

```swift
let helpResult = await apiService.getAssignmentHelp(
    assignmentId: assignment.canvasAssignmentId,
    courseId: assignment.courseId,
    question: question,
    helpType: "research"
)

if let result = helpResult {
    response = result.content
    
    // Convert sources to Citation objects if needed
    if let sources = result.sources {
        let citations = sources.compactMap { sourceDict -> Citation? in
            guard let id = sourceDict["id"],
                  let title = sourceDict["title"],
                  let url = sourceDict["url"] else { return nil }
            return Citation(
                id: id, 
                title: title, 
                url: url, 
                snippet: sourceDict["snippet"]
            )
        }
        
        // Display with citations
        MarkdownView(content: response, sources: citations)
    }
}
```

## Troubleshooting

### Issue: No citations appear

**Check:**
1. Is Perplexity API key configured?
2. Is help type set to "research", "solution", or "analysis"?
3. Check backend logs for Perplexity errors

**Solution:**
```bash
# Verify Perplexity is configured
echo $PERPLEXITY_API_KEY

# Check logs
tail -f canvas_automation.log | grep -i perplexity
```

### Issue: Still getting 400 error

**Check:**
1. Assignment ID is being sent
2. Course ID is being sent
3. Backend logs show what's missing

**Debug:**
```swift
print("Sending help request:")
print("  Assignment ID: \(assignment.canvasAssignmentId)")
print("  Course ID: \(assignment.courseId)")
print("  Question: \(question)")
print("  Help Type: \(helpType)")
```

### Issue: Generic responses (not context-aware)

**Check:**
1. Course context is being fetched
2. Assignment type is being detected
3. Prompt templates are being used

**Solution:** Verify backend is using `PromptTemplates.get_assignment_help_prompt()`

### Issue: Response not formatted properly

**Check:**
1. Using `MarkdownView` instead of `Text` or `MathFormattedText`
2. Response includes Markdown formatting
3. LaTeX is wrapped in `$...$` or `$$...$$`

## Future Enhancements

### Planned Features

1. **Source Preview:**
   - Hover over `[1]` to see snippet
   - Quick preview without scrolling

2. **History:**
   - Save previous AI help sessions
   - Quick access to past responses

3. **Smart Follow-ups:**
   - Suggest related questions
   - "Ask me more" button

4. **Collaborative Help:**
   - Share AI responses with classmates
   - Anonymous help sharing

5. **Performance Tracking:**
   - Track which help types are most effective
   - Correlate with assignment grades

## Summary

✅ **Full AI Help & Analysis implementation**  
✅ **4 specialized help types** with different AI backends  
✅ **Context-aware prompts** using course and assignment data  
✅ **Beautiful rendering** with Markdown, LaTeX, and citations  
✅ **Multiple entry points** (detail view button + swipe action)  
✅ **Proper error handling** and logging  
✅ **Source citations** with clickable links  

The system is now fully functional and ready to help students with any assignment!

