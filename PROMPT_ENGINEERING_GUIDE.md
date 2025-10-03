# Prompt Engineering & Context System

## Overview

The Canvas Automation Flow now features a **modularized, context-aware prompt system** that delivers specialized AI responses based on:
- Entry point (where the request comes from)
- Assignment type (discussion, essay, problem set, research, etc.)
- Course context (subject, materials, previous work)
- Student's academic level

## Architecture

### Prompt Templates Module
**Location:** `src/llm/prompt_templates.py`

**Key Components:**
1. `PromptType` - Enum defining different AI assistance types
2. `PromptContext` - Dataclass holding contextual information
3. `PromptTemplates` - Class with specialized prompt generators

### Context Information

The system automatically gathers context from:
- **Course data:** Name, subject, materials, syllabus
- **Assignment details:** Type, due date, points, requirements
- **Student history:** Previous grades, level, performance patterns
- **Uploaded files:** Context documents provided by student

## Prompt Specialization

### 1. Discussion Board Assignments

**Detected by:** Keywords like "discussion", "forum", "post", "respond"

**Specialized prompt focuses on:**
- Understanding discussion prompts
- Developing thoughtful arguments
- Peer engagement strategies
- Scholarly tone and citations
- Connection to course themes

**Entry points:**
- Assignment list swipe → "AI Help"
- Assignment detail view → "Get AI Help"
- AI Assistant tab → Select discussion assignment

### 2. Problem-Solving Assignments

**Detected by:** Keywords like "problem set", "homework", "exercises", "calculations"

**Specialized prompt focuses on:**
- Step-by-step problem analysis
- Mathematical notation and LaTeX
- Solution verification
- Alternative approaches
- Showing work clearly

**Entry points:**
- Assignment list swipe → "AI Help"
- Assignment detail view with math context
- AI Assistant → Problem solving mode

### 3. Essay Assignments

**Detected by:** Keywords like "essay", "paper", "write", "composition"

**Specialized prompt focuses on:**
- Thesis development
- Essay structure and outline
- Academic writing standards
- Source integration
- Revision strategies

**Entry points:**
- Assignment detail → "AI Help" with essay prompt
- AI Assistant → Essay writing mode
- Complete assignment feature

### 4. Research Assignments

**Detected by:** Keywords like "research", "investigate", "analyze", "study"

**Specialized prompt focuses on:**
- Research question formulation
- Source identification with citations
- Critical analysis
- Synthesis of findings
- Proper attribution

**Entry points:**
- Assignment detail → "AI Help"
- AI Assistant → Research mode
- With Perplexity enabled for citations

### 5. Concept Explanation

**Used for:** Understanding course material

**Specialized prompt focuses on:**
- Clear definitions
- Examples at appropriate level
- Visual/structural understanding
- Common misconceptions
- Connection to broader themes

**Entry points:**
- Dashboard → "Explain Any Concept"
- AI Assistant → Concept Explainer
- Assignment help → Understanding prerequisites

## Context-Aware Features

### Course Context Integration

When a student requests help, the system:
1. Fetches course information from Canvas
2. Retrieves course materials and syllabus
3. Checks student's previous performance
4. Uses rubrics if available

**Example:**
```python
prompt_context = PromptContext(
    course_name="Introduction to Psychology",
    course_subject="PSYCH 101",
    assignment_type="discussion_post",
    due_date="2025-10-05",
    points_possible=10.0,
    student_level="undergraduate"
)
```

### Dynamic Prompt Generation

The system selects the appropriate prompt based on:

```python
# Detect assignment type from name and description
assignment_type = PromptTemplates._detect_assignment_type(
    "Introductions Discussion Board",
    "Post a brief introduction..."
)
# Returns: "discussion"

# Generate specialized prompt
prompt = PromptTemplates.get_assignment_help_prompt(
    assignment_name="Introductions Discussion Board",
    assignment_description="Post a brief introduction...",
    question="Help me write an introduction",
    context=prompt_context
)
```

### Entry Point Optimization

Different entry points use different prompt strategies:

| Entry Point | Prompt Strategy | AI Service | Temperature |
|-------------|----------------|------------|-------------|
| Assignment swipe help | Quick, focused guidance | Perplexity | 0.5 |
| Assignment detail help | Detailed, contextual | Perplexity | 0.5 |
| Complete assignment | Full, research-backed | Perplexity | 0.3 |
| Concept explainer | Educational, clear | Perplexity/Groq | 0.3 |
| Quiz assistance | Precise, accurate | Perplexity | 0.1 |
| Study plan | Strategic, organized | Groq | 0.3 |

## System Prompts

### Absolute Mode
**Used for:** Direct, no-nonsense responses
- Eliminates filler and motivational content
- Blunt, directive phrasing
- Focus on cognitive rebuilding
- Terminates after delivering information

### Academic Tutor
**Used for:** Educational assistance
- Clear, accurate explanations
- Break down complex concepts
- Encourage critical thinking
- Connect concepts to broader themes

### Research Assistant
**Used for:** Research-heavy work
- Accurate, well-researched information
- Include citations from reliable sources
- Present multiple perspectives
- Guide proper citation practices

## API Integration

### Updated Endpoints

#### `/api/ai/assignment-help`
```json
POST /api/ai/assignment-help
{
  "assignment_id": "12345",
  "course_id": "67890",
  "question": "Help me understand this prompt"
}

Response:
{
  "assignment": {...},
  "help": "Detailed, context-aware response...",
  "model": "sonar",
  "sources": [
    {"id": "1", "title": "...", "url": "..."}
  ]
}
```

**Features:**
- Automatically detects assignment type
- Fetches course context
- Uses appropriate prompt template
- Returns with citations if using Perplexity

#### `/api/ai/explain-concept`
```json
POST /api/ai/explain-concept
{
  "concept": "Discrete Mathematics",
  "context": "Working on a logic assignment",
  "level": "undergraduate",
  "course_id": "67890"  // Optional
}

Response:
{
  "concept": "Discrete Mathematics",
  "explanation": "Comprehensive explanation with examples...",
  "model": "sonar",
  "sources": [...]
}
```

**Features:**
- Adapts to student level
- Uses course context if provided
- Includes examples at appropriate level
- Returns research sources

## Prompt Engineering Best Practices

### 1. Context is King
Always include:
- Course information
- Assignment requirements
- Student's academic level
- Available materials
- Due dates and points

### 2. Assignment Type Detection
Keywords to watch for:
- **Discussion:** "discuss", "forum", "post", "respond", "reply"
- **Problem Set:** "problem", "exercise", "calculate", "solve", "homework"
- **Essay:** "essay", "write", "paper", "compose", "argument"
- **Research:** "research", "investigate", "analyze", "study", "examine"

### 3. Temperature Settings
- **Factual/Precise:** 0.1-0.2 (quizzes, calculations)
- **Explanatory:** 0.3-0.4 (concepts, problem-solving)
- **Creative/Exploratory:** 0.5-0.7 (discussions, essays)

### 4. Token Limits
- Quick help: 500-800 tokens
- Detailed explanation: 1200-1500 tokens
- Full completion: 2000-3000 tokens

## Troubleshooting

### Issue: Generic Responses
**Solution:** Ensure course_id is passed for context

### Issue: Wrong Assignment Type Detected
**Solution:** Update keywords in `_detect_assignment_type()`

### Issue: No Citations
**Solution:** Verify Perplexity API key is set and working

### Issue: Response Too Technical/Simple
**Solution:** Adjust student_level in PromptContext

## Testing Different Entry Points

### Test Discussion Board Help
```bash
curl -X POST http://localhost:5000/api/ai/assignment-help \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "assignment_id": "12345",
    "course_id": "67890",
    "question": "Help me write an introduction post"
  }'
```

### Test Concept Explanation
```bash
curl -X POST http://localhost:5000/api/ai/explain-concept \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "concept": "Discrete Math",
    "context": "Logic and proofs",
    "level": "undergraduate",
    "course_id": "67890"
  }'
```

## Future Enhancements

### Planned Features
1. **Rubric Integration:** Parse and use rubric criteria in prompts
2. **Previous Submissions:** Learn from student's writing style
3. **Syllabus Analysis:** Extract key themes and requirements
4. **Peer Examples:** Show anonymized examples from high-scoring submissions
5. **Progressive Disclosure:** Reveal help incrementally to encourage learning

### Advanced Context
- Student's GPA and performance trends
- Time of semester (early vs. late)
- Professor's teaching style and preferences
- Class discussion patterns
- Assignment difficulty ratings

## Summary

The new prompt system provides:

✅ **Context-aware responses** based on course and assignment type  
✅ **Specialized prompts** for different entry points  
✅ **Real student data** integration from Canvas  
✅ **Intelligent assignment detection** from descriptions  
✅ **Proper citations** when using Perplexity  
✅ **Adaptive difficulty** based on student level  

This ensures students receive the most relevant, helpful assistance for their specific academic needs.

