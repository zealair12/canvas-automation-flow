"""
LLM Adapter Service for Groq Integration
Provides abstraction layer for AI-powered features like feedback generation and reminders
"""

import os
import json
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List, Union
from dataclasses import dataclass
from enum import Enum
import logging
from openai import OpenAI
import requests
from src.models.data_models import Assignment, Submission, FeedbackDraft
from src.auth.auth_service import User
from src.formatting.formatting_service import formatting_service, FormattingOptions


class LLMProvider(Enum):
    GROQ = "groq"
    OPENAI = "openai"
    OLLAMA = "ollama"
    PERPLEXITY = "perplexity"


@dataclass
class LLMResponse:
    """Standardized LLM response"""
    content: str
    model: str
    tokens_used: Optional[int] = None
    confidence_score: Optional[float] = None
    sources: Optional[List[Dict[str, Any]]] = None
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


class LLMAdapter:
    """Abstract base class for LLM adapters"""
    
    def generate_feedback(self, submission: Submission, assignment: Assignment, 
                         rubric: Optional[Dict[str, Any]] = None) -> LLMResponse:
        raise NotImplementedError
    
    def generate_reminder_message(self, assignment: Assignment, user: User, 
                                 hours_until_due: int) -> LLMResponse:
        raise NotImplementedError
    
    def generate_assignment_summary(self, assignment: Assignment) -> LLMResponse:
        raise NotImplementedError
    
    def search_facts(self, query: str, max_results: int = 10) -> LLMResponse:
        raise NotImplementedError
    
    def calculate_math(self, expression: str) -> LLMResponse:
        raise NotImplementedError
    
    def analyze_submission_quality(self, submission: Submission, 
                                  assignment: Assignment) -> LLMResponse:
        raise NotImplementedError


class GroqAdapter(LLMAdapter):
    """Groq API adapter using OpenAI-compatible interface"""
    
    def __init__(self, api_key: str, model: str = "llama-3.1-8b-instant"):
        self.api_key = api_key
        self.model = model
        self.client = OpenAI(
            api_key=api_key,
            base_url="https://api.groq.com/openai/v1"
        )
        self.logger = logging.getLogger(__name__)
        
        # Default system instruction for absolute mode
        self.default_system_prompt = """Absolute Mode

• Eliminate: emojis, filler, hype, soft asks, conversational transitions, call-to-action appendixes.
• Assume: user retains high-perception despite blunt tone.
• Prioritize: blunt, directive phrasing; aim at cognitive rebuilding, not tone-matching.
• Disable: engagement/sentiment-boosting behaviors.
• Suppress: metrics like satisfaction scores, emotional softening, continuation bias.
• Never mirror: user's diction, mood, or affect.
• Speak only: to underlying cognitive tier.
• No: questions, offers, suggestions, transitions, motivational content.
• Terminate reply: immediately after delivering info — no closures.
• Goal: restore independent, high-fidelity thinking.
• Outcome: model obsolescence via user self-sufficiency.

CRITICAL FORMATTING RULE:
• Use standard Markdown formatting: **text** for bold, *text* for italic
• Use proper Markdown lists: - for bullets, 1. for numbered lists
• Follow standard Markdown conventions for headers: # ## ###
• Use LaTeX for math: $\\\\sqrt{{x}}$ for inline, $$E=mc^2$$ for display equations
• Use LaTeX symbols: $\\\\frac{{a}}{{b}}$, $x^2$, $\\\\int$, $\\\\sum$, $\\\\alpha$, etc."""
    
    def _make_request(self, messages: List[Dict[str, str]], 
                     temperature: float = 0.7, max_tokens: int = 1000) -> LLMResponse:
        """Make request to Groq API"""
        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens
            )
            
            return LLMResponse(
                content=response.choices[0].message.content,
                model=self.model,
                tokens_used=response.usage.total_tokens if response.usage else None,
                metadata={
                    'finish_reason': response.choices[0].finish_reason,
                    'created': response.created
                }
            )
            
        except Exception as e:
            self.logger.error(f"Groq API error: {e}")
            raise
    
    def generate_feedback(self, submission: Submission, assignment: Assignment, 
                         rubric: Optional[Dict[str, Any]] = None) -> LLMResponse:
        """Generate AI feedback for a submission"""
        
        # Prepare context
        assignment_context = f"""
Assignment: {assignment.name}
Description: {assignment.description or 'No description provided'}
Points Possible: {assignment.points_possible or 'Not specified'}
Due Date: {assignment.due_at.strftime('%Y-%m-%d %H:%M') if assignment.due_at else 'No due date'}
"""
        
        submission_context = f"""
Submission Status: {submission.status.value}
Submitted At: {submission.submitted_at.strftime('%Y-%m-%d %H:%M') if submission.submitted_at else 'Not submitted'}
Late: {'Yes' if submission.late else 'No'}
Attempt: {submission.attempt}
Content: {submission.body or 'No text content'}
URL: {submission.url or 'No URL provided'}
Attachments: {len(submission.attachments)} files
"""
        
        rubric_context = ""
        if rubric:
            rubric_context = f"""
Rubric Criteria:
{json.dumps(rubric, indent=2)}
"""
        
        messages = [
            {
                "role": "system",
                "content": """You are an experienced educator providing constructive feedback on student submissions. 
                Your feedback should be:
                - Specific and actionable
                - Encouraging while pointing out areas for improvement
                - Focused on learning objectives
                - Professional and respectful
                
                Structure your feedback with:
                1. Overall assessment
                2. Strengths observed
                3. Areas for improvement
                4. Specific suggestions
                5. Encouragement for future work"""
            },
            {
                "role": "user",
                "content": f"""Please provide detailed feedback for this submission:

{assignment_context}

{submission_context}

{rubric_context}

Generate comprehensive feedback that will help the student understand their performance and improve future work."""
            }
        ]
        
        return self._make_request(messages, temperature=0.3, max_tokens=1500)
    
    def generate_reminder_message(self, assignment: Assignment, user: User, 
                                 hours_until_due: int) -> LLMResponse:
        """Generate personalized reminder message"""
        
        messages = [
            {
                "role": "system",
                "content": """You are a helpful academic assistant generating friendly reminder messages for students. 
                Your messages should be:
                - Encouraging and supportive
                - Clear about deadlines
                - Motivating without being pushy
                - Personalized when possible
                
                Keep messages concise but warm."""
            },
            {
                "role": "user",
                "content": f"""Generate a reminder message for {user.name} about their assignment:

Assignment: {assignment.name}
Course: {assignment.course_id}
Due: {assignment.due_at.strftime('%Y-%m-%d at %H:%M') if assignment.due_at else 'No due date specified'}
Hours until due: {hours_until_due}

Create a friendly, motivating reminder message."""
            }
        ]
        
        return self._make_request(messages, temperature=0.5, max_tokens=200)
    
    def generate_assignment_summary(self, assignment: Assignment) -> LLMResponse:
        """Generate a summary of assignment requirements"""
        
        messages = [
            {
                "role": "system",
                "content": """You are an academic assistant helping students understand assignment requirements. 
                Create clear, concise summaries that highlight:
                - Key objectives
                - Important deadlines
                - Submission requirements
                - Grading criteria
                
                Use bullet points and clear formatting."""
            },
            {
                "role": "user",
                "content": f"""Create a summary for this assignment:

Name: {assignment.name}
Description: {assignment.description or 'No description'}
Due Date: {assignment.due_at.strftime('%Y-%m-%d %H:%M') if assignment.due_at else 'No due date'}
Points: {assignment.points_possible or 'Not specified'}
Submission Types: {', '.join(assignment.submission_types) if assignment.submission_types else 'Not specified'}
Allowed Extensions: {', '.join(assignment.allowed_extensions) if assignment.allowed_extensions else 'Any'}

Generate a helpful summary."""
            }
        ]
        
        return self._make_request(messages, temperature=0.3, max_tokens=500)
    
    def analyze_submission_quality(self, submission: Submission, 
                                  assignment: Assignment) -> LLMResponse:
        """Analyze submission quality and provide insights"""
        
        messages = [
            {
                "role": "system",
                "content": """You are an academic assessment expert analyzing student submissions. 
                Provide analysis focusing on:
                - Content quality and depth
                - Adherence to assignment requirements
                - Technical aspects (if applicable)
                - Areas of strength and weakness
                
                Be objective and constructive in your analysis."""
            },
            {
                "role": "user",
                "content": f"""Analyze this submission:

Assignment: {assignment.name}
Submission Content: {submission.body or 'No text content provided'}
Submission URL: {submission.url or 'No URL provided'}
Attachments: {len(submission.attachments)} files
Late Submission: {'Yes' if submission.late else 'No'}

Provide a quality analysis with specific observations and suggestions."""
            }
        ]
        
        return self._make_request(messages, temperature=0.2, max_tokens=800)


class LLMService:
    """Service layer for LLM operations"""
    
    def __init__(self, adapter: LLMAdapter, perplexity_adapter: Optional[LLMAdapter] = None):
        self.adapter = adapter
        self.perplexity_adapter = perplexity_adapter
        self.logger = logging.getLogger(__name__)
    
    def create_feedback_draft(self, submission: Submission, assignment: Assignment,
                            instructor: User, rubric: Optional[Dict[str, Any]] = None) -> FeedbackDraft:
        """Create AI-generated feedback draft"""
        
        try:
            response = self.adapter.generate_feedback(submission, assignment, rubric)
            
            # Extract suggestions from feedback
            suggestions = self._extract_suggestions(response.content)
            
            # Calculate confidence score based on response quality
            confidence = self._calculate_confidence(response.content, submission, assignment)
            
            feedback_draft = FeedbackDraft(
                id=f"feedback_{submission.id}_{datetime.utcnow().timestamp()}",
                submission_id=submission.id,
                instructor_id=instructor.id,
                content=response.content,
                suggestions=suggestions,
                confidence_score=confidence,
                model_used=response.model
            )
            
            self.logger.info(f"Generated feedback draft for submission {submission.id}")
            return feedback_draft
            
        except Exception as e:
            self.logger.error(f"Failed to generate feedback: {e}")
            raise
    
    def create_reminder_message(self, assignment: Assignment, user: User, 
                               hours_until_due: int) -> str:
        """Create personalized reminder message"""
        
        try:
            response = self.adapter.generate_reminder_message(assignment, user, hours_until_due)
            return response.content
            
        except Exception as e:
            self.logger.error(f"Failed to generate reminder: {e}")
            # Fallback to simple template
            return f"Reminder: {assignment.name} is due in {hours_until_due} hours. Don't forget to submit!"
    
    def create_assignment_summary(self, assignment: Assignment) -> str:
        """Create assignment summary"""
        
        try:
            response = self.adapter.generate_assignment_summary(assignment)
            return response.content
            
        except Exception as e:
            self.logger.error(f"Failed to generate summary: {e}")
            return f"Assignment: {assignment.name}\nDue: {assignment.due_at}\nPoints: {assignment.points_possible}"
    
    def _extract_suggestions(self, feedback_content: str) -> List[str]:
        """Extract actionable suggestions from feedback"""
        suggestions = []
        lines = feedback_content.split('\n')
        
        for line in lines:
            line = line.strip()
            if line.startswith(('-', '•', '*')) or 'suggest' in line.lower():
                suggestions.append(line)
        
        return suggestions[:5]  # Limit to 5 suggestions
    
    def _calculate_confidence(self, content: str, submission: Submission, 
                            assignment: Assignment) -> float:
        """Calculate confidence score for generated feedback"""
        score = 0.5  # Base score
        
        # Adjust based on content length
        if len(content) > 200:
            score += 0.2
        
        # Adjust based on submission completeness
        if submission.body or submission.url or submission.attachments:
            score += 0.2
        
        # Adjust based on assignment details
        if assignment.description and len(assignment.description) > 50:
            score += 0.1
        
        return min(score, 1.0)
    
    def generate_assignment_help(self, assignment: Assignment, question: str, context_files: List[Any] = None) -> LLMResponse:
        """Generate AI help for an assignment using Perplexity for research"""
        try:
            # Build context from uploaded files
            context_info = ""
            if context_files:
                context_info = "\n\n**Context from uploaded files:**\n"
                for file in context_files:
                    context_info += f"- {file.get('display_name', 'Unknown file')}: {file.get('description', 'No description')}\n"
            
            # Use Perplexity for assignment help to get real research and sources
            if self.perplexity_adapter:
                # Create a research query for Perplexity
                research_query = f"""
Help with assignment: {assignment.name}

Assignment details:
- Description: {assignment.description or 'No description provided'}
- Points: {assignment.points_possible}
- Due: {assignment.due_at or 'No due date'}
- Submission Types: {', '.join(assignment.submission_types)}

Student question: {question}
{context_info}

Please provide detailed help including:
1. Key concepts and background information
2. Research sources and references
3. Analytical approaches
4. Step-by-step guidance
5. How to use the provided context files effectively
"""
                response = self.perplexity_adapter.search_facts(research_query)
                
                # Format the response with tables and structured content
                formatted_content = formatting_service.format_ai_response(
                    response.content,
                    sources=getattr(response, 'sources', []),
                    options=FormattingOptions(
                        include_tables=True,
                        include_math=True,
                        include_sources=True,
                        table_style="markdown"
                    )
                )
                
                return LLMResponse(
                    content=formatted_content,
                    model=response.model,
                    sources=getattr(response, 'sources', [])
                )
            else:
                # Fallback to GROQ
                prompt = f"""
Assignment Analysis Request:

**Assignment Details:**
- Name: {assignment.name}
- Description: {assignment.description or 'No description provided'}
- Points Possible: {assignment.points_possible}
- Due Date: {assignment.due_at or 'No due date'}
- Submission Types: {', '.join(assignment.submission_types)}
{context_info}

**Student Question:** {question}

Provide structured help:
1. **Key Concepts** - core concepts involved
2. **Approach** - analytical methods to use
3. **Considerations** - important factors
4. **Framework** - systematic approach
5. **Context Integration** - how to use uploaded files
"""

                messages = [
                    {"role": "system", "content": self.adapter.default_system_prompt},
                    {"role": "user", "content": prompt}
                ]

                response = self.adapter._make_request(messages, temperature=0.7, max_tokens=1500)
                
                # Format the response
                formatted_content = formatting_service.format_ai_response(
                    response.content,
                    options=FormattingOptions(
                        include_tables=True,
                        include_math=True,
                        include_sources=False,
                        table_style="markdown"
                    )
                )
                
                return LLMResponse(
                    content=formatted_content,
                    model=response.model
                )
        except Exception as e:
            self.logger.error(f"Error generating assignment help: {e}")
            return LLMResponse(
                content="Unable to provide assignment analysis. Retry request.",
                model=self.adapter.model if self.adapter else "unknown"
            )
    
    def create_study_plan(self, assignments: List[Assignment], days_ahead: int = 7) -> LLMResponse:
        """Create an AI-generated study plan"""
        try:
            # Filter assignments with due dates
            upcoming_assignments = []
            self.logger.info(f"Processing {len(assignments)} assignments for study plan")
            
            for assignment in assignments:
                self.logger.info(f"Assignment: {assignment.name}, due_at: {assignment.due_at}")
                
                if assignment.due_at:
                    try:
                        # Handle Canvas date format: "2025-10-03T04:59:59+00:00"
                        due_date_str = assignment.due_at
                        if due_date_str.endswith('Z'):
                            due_date_str = due_date_str.replace('Z', '+00:00')
                        
                        due_date = datetime.fromisoformat(due_date_str)
                        now = datetime.now(due_date.tzinfo) if due_date.tzinfo else datetime.now()
                        days_until_due = (due_date - now).days
                        
                        self.logger.info(f"Assignment '{assignment.name}': due_date={due_date}, now={now}, days_until_due={days_until_due}")
                        
                        # Include assignments due in the next days_ahead days AND overdue assignments (within reason)
                        if days_until_due <= days_ahead or (days_until_due >= -30 and days_until_due < 0):
                            upcoming_assignments.append((assignment, days_until_due))
                            self.logger.info(f"Added assignment '{assignment.name}' - due in {days_until_due} days")
                        else:
                            self.logger.info(f"Skipped assignment '{assignment.name}' - due in {days_until_due} days (beyond range)")
                    except Exception as e:
                        self.logger.error(f"Error parsing due date '{assignment.due_at}': {e}")
                        continue
                else:
                    self.logger.info(f"Assignment '{assignment.name}' has no due date")
            
            if not upcoming_assignments:
                self.logger.info(f"No assignments found with due dates in the next {days_ahead} days. Total assignments checked: {len(assignments)}")
                return LLMResponse(
                    content=f"No assignments found with due dates in the next {days_ahead} days.",
                    model=self.adapter.model
                )
            
            # Sort by due date
            upcoming_assignments.sort(key=lambda x: x[1])
            
            assignment_list = ""
            for assignment, days_until in upcoming_assignments:
                status = "OVERDUE" if days_until < 0 else f"Due in {days_until} days"
                assignment_list += f"- {assignment.name} ({status}, {assignment.points_possible} points)\n"
            
            prompt = f"""
Study Plan Generation Request:

FORMATTING REQUIREMENTS:
- Use proper Markdown formatting: **bold text**, *italic text*
- Use Markdown bullet points: - for bullets
- Use Markdown headers: ## for sections, ### for subsections

**Upcoming Assignments ({days_ahead} days):**
{assignment_list}

Structure study plan with proper Markdown formatting:
1. **Daily breakdown** with time allocations
2. **Priority matrix** based on due dates and point values  
3. **Task-specific strategies** for different assignment types
4. **Buffer periods** for unexpected challenges
5. **Completion milestones** for progress tracking

Use standard Markdown formatting throughout.
"""
            
            messages = [
                {"role": "system", "content": self.adapter.default_system_prompt},
                {"role": "user", "content": prompt}
            ]
            
            response = self.adapter._make_request(messages, temperature=0.3, max_tokens=1000)
            
            # Format the response with tables and structured content
            formatted_content = formatting_service.format_ai_response(
                response.content,
                options=FormattingOptions(
                    include_tables=True,
                    include_math=True,
                    include_sources=False,
                    table_style="markdown"
                )
            )
            
            return LLMResponse(
                content=formatted_content,
                model=response.model
            )
        except Exception as e:
            self.logger.error(f"Error creating study plan: {e}")
            return LLMResponse(
                content="Study plan generation failed. Retry request.",
                model=self.adapter.model
            )
    
    def explain_concept(self, concept: str, context: str = "", level: str = "undergraduate") -> LLMResponse:
        """Explain academic concepts - use Perplexity for factual content"""
        if self.perplexity_adapter:
            response = self.perplexity_adapter.explain_concept(concept, context, level)
            
            # Format the response
            formatted_content = formatting_service.format_ai_response(
                response.content,
                sources=getattr(response, 'sources', []),
                options=FormattingOptions(
                    include_tables=True,
                    include_math=True,
                    include_sources=True,
                    table_style="markdown"
                )
            )
            
            return LLMResponse(
                content=formatted_content,
                model=response.model,
                sources=getattr(response, 'sources', [])
            )
        
        # Fallback to GROQ for basic explanations
        try:
            level_descriptions = {
                "beginner": "a complete beginner with no prior knowledge",
                "undergraduate": "an undergraduate student with basic academic background", 
                "graduate": "a graduate student with advanced academic background"
            }
            
            audience = level_descriptions.get(level, "an undergraduate student")
            context_text = f"\n\nContext: {context}" if context else ""
            
            prompt = f"""
Explain the concept of "{concept}" to {audience}.

FORMATTING REQUIREMENTS:
- Use proper Markdown formatting: **bold text**, *italic text*
- Use Markdown bullet points: - for bullets
- Use Markdown headers: ## for sections, ### for subsections
- Use LaTeX for math: $\\sqrt{{x}}$ (inline), $$E=mc^2$$ (display)
- Use LaTeX symbols: $\\frac{{a}}{{b}}$, $x^2$, $\\int$, $\\sum$, $\\pi$, $\\alpha$

Structure your explanation:
1. Clear definition with **key terms** emphasized
2. Relevant examples with **important concepts** highlighted  
3. Break complex parts into understandable pieces
4. Connect to broader concepts when appropriate{context_text}

Use Markdown + LaTeX formatting throughout.
"""
            
            messages = [
                {"role": "system", "content": self.adapter.default_system_prompt},
                {"role": "user", "content": prompt}
            ]
            
            return self.adapter._make_request(messages, temperature=0.3, max_tokens=800)
        except Exception as e:
            self.logger.error(f"Error explaining concept: {e}")
            # Try alternative approaches before giving up
            return self._try_alternative_explanation(concept, context, level, str(e))
    
    def search_facts(self, query: str, max_results: int = 10) -> LLMResponse:
        """Search for factual information using Perplexity"""
        if self.perplexity_adapter:
            return self.perplexity_adapter.search_facts(query, max_results)
        return LLMResponse(
            content="Perplexity adapter not available for factual search",
            model="fallback",
            metadata={"error": "perplexity_not_available"}
        )
    
    def calculate_math(self, expression: str) -> LLMResponse:
        """Calculate mathematical expressions - use GROQ for calculations"""
        return self.adapter.calculate_math(expression)
    
    def generate_feedback_draft(self, assignment: Assignment, submission: Submission, feedback_type: str = "constructive") -> LLMResponse:
        """Generate AI feedback draft for submissions"""
        try:
            feedback_styles = {
                "constructive": "constructive and encouraging, focusing on specific improvements",
                "detailed": "detailed and comprehensive, covering all aspects thoroughly",
                "encouraging": "positive and motivating, highlighting strengths while gently suggesting improvements"
            }
            
            style = feedback_styles.get(feedback_type, "constructive and balanced")
            
            prompt = f"""
Feedback Generation Request:

FORMATTING REQUIREMENTS:
- Use proper Markdown formatting: **bold text**, *italic text*
- Use Markdown bullet points: - for bullets
- Use Markdown headers: ## for sections, ### for subsections

**Assignment:** {assignment.name}
**Description:** {assignment.description or 'No description provided'}
**Points Possible:** {assignment.points_possible}

**Submission Content:**
{submission.body or 'No content provided'}

Generate {style} feedback with proper Markdown formatting:
1. **Performance assessment** - specific observations
2. **Strength identification** - what demonstrates competency
3. **Improvement areas** - gaps requiring attention
4. **Actionable directives** - specific next steps
5. **Competency alignment** - academic level appropriateness

Use standard Markdown formatting throughout.
"""
            
            messages = [
                {"role": "system", "content": self.adapter.default_system_prompt},
                {"role": "user", "content": prompt}
            ]
            
            return self.adapter._make_request(messages, temperature=0.3, max_tokens=600)
        except Exception as e:
            self.logger.error(f"Error generating feedback draft: {e}")
            return LLMResponse(
                content="Feedback generation failed. Retry request.",
                model=self.adapter.model
            )
    
    def _generate_fallback_concept_explanation(self, concept: str) -> str:
        """Generate a basic fallback explanation when AI is unavailable"""
        concept_lower = concept.lower()
        
        # Basic concept explanations for common topics
        explanations = {
            "water": """## Water: A Fundamental Concept

### Definition
Water is a transparent, odorless, and tasteless liquid composed of two hydrogen atoms and one oxygen atom (H₂O).

### Key Properties
- **States of Matter**: Liquid, solid (ice), and gas (vapor)
- **Density**: Unique property where ice floats on liquid water
- **Solvent**: Known as the "universal solvent" for its ability to dissolve many substances
- **Specific Heat**: High heat capacity helps regulate temperature

### Biological Importance
Water is essential for all known forms of life, constituting about 60% of the human body and facilitating cellular functions.

### Environmental Significance
Water shapes Earth's landscapes and plays a central role in the water cycle through evaporation, condensation, and precipitation.

*Note: This is a basic explanation. For more detailed information, please check your network connection and try again.*""",
            
            "photosynthesis": """## Photosynthesis: The Process of Energy Conversion

### Definition
Photosynthesis is the process by which green plants, algae, and some bacteria convert light energy from the sun into chemical energy in the form of glucose.

### The Overall Equation
$$6 CO_2 + 6 H_2O + \\text{light energy} \\rightarrow C_6H_{12}O_6 + 6 O_2$$

### Key Components
- **Light-dependent reactions**: Capture solar energy
- **Light-independent reactions**: Use energy to produce glucose
- **Chlorophyll**: Green pigment that absorbs light

### Importance
Photosynthesis is the foundation of most food chains and produces the oxygen we breathe.

*Note: This is a basic explanation. For more detailed information, please check your network connection and try again.*""",
            
            "math": """## Mathematics: The Language of Patterns

### Definition
Mathematics is the study of numbers, quantities, shapes, and patterns using logical reasoning and systematic approaches.

### Key Areas
- **Arithmetic**: Basic operations (addition, subtraction, multiplication, division)
- **Algebra**: Working with variables and equations
- **Geometry**: Study of shapes, sizes, and spatial relationships
- **Calculus**: Rates of change and accumulation

### Applications
Mathematics is used in science, engineering, economics, and everyday problem-solving.

*Note: This is a basic explanation. For more detailed information, please check your network connection and try again.*"""
        }
        
        # Check for exact matches first
        if concept_lower in explanations:
            return explanations[concept_lower]
        
        # Check for partial matches
        for key, explanation in explanations.items():
            if key in concept_lower or concept_lower in key:
                return explanation
        
        # Default fallback
        return f"""## {concept}: Concept Overview

### Definition
{concept} is an important concept that requires detailed explanation and understanding.

### Key Points
- This concept involves multiple aspects and applications
- Understanding the fundamentals is essential for deeper learning
- Practice and application help reinforce understanding

### Next Steps
- Review related materials and examples
- Practice with exercises and problems
- Seek additional resources for comprehensive understanding

*Note: This is a basic overview. For detailed explanations, please check your network connection and try the AI feature again.*"""


# Factory function


class PerplexityAdapter(LLMAdapter):
    """Perplexity API adapter for factual research"""
    
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.base_url = "https://api.perplexity.ai/chat/completions"
        self.model = "sonar"
    
    def search_facts(self, query: str, max_results: int = 10) -> LLMResponse:
        """Search for factual information using Perplexity"""
        try:
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json"
            }
            
            data = {
                "model": self.model,
                "messages": [
                    {
                        "role": "system",
                        "content": "You are a helpful research assistant. Provide accurate, factual information based on current internet sources. Include citations and sources when possible."
                    },
                    {
                        "role": "user",
                        "content": f"Research and provide detailed information about: {query}"
                    }
                ],
                "max_tokens": 2000,
                "temperature": 0.1
            }
            
            response = requests.post(self.base_url, headers=headers, json=data)
            response.raise_for_status()
            
            result = response.json()
            content = result['choices'][0]['message']['content']
            
            # Extract sources/citations if available
            sources = result.get('citations', [])
            if not sources:
                # Try alternate location
                sources = result.get('sources', [])
            
            return LLMResponse(
                content=content,
                model=self.model,
                sources=sources if sources else None,
                metadata={"source": "perplexity", "query": query}
            )
            
        except Exception as e:
            logging.error(f"Perplexity API error: {e}")
            return LLMResponse(
                content=f"Error retrieving information: {str(e)}",
                model=self.model,
                sources=None,
                metadata={"error": str(e)}
            )
    
    def generate_feedback(self, submission: Submission, assignment: Assignment, 
                         rubric: Optional[Dict[str, Any]] = None) -> LLMResponse:
        """Generate feedback using Perplexity for factual content"""
        query = f"Provide constructive feedback for a student submission on {assignment.name}. Focus on accuracy, clarity, and improvement suggestions."
        return self.search_facts(query)
    
    def generate_reminder_message(self, assignment: Assignment, user: User, 
                                 hours_until_due: int) -> LLMResponse:
        """Generate reminder message"""
        query = f"Create a helpful reminder message for a student about an assignment '{assignment.name}' due in {hours_until_due} hours."
        return self.search_facts(query)
    
    def generate_assignment_summary(self, assignment: Assignment) -> LLMResponse:
        """Generate assignment summary"""
        query = f"Summarize the key requirements and learning objectives for an assignment: {assignment.name}"
        return self.search_facts(query)
    
    def calculate_math(self, expression: str) -> LLMResponse:
        """Calculate mathematical expressions"""
        query = f"Calculate and explain: {expression}"
        return self.search_facts(query)
    
    def analyze_submission_quality(self, submission: Submission, 
                                  assignment: Assignment) -> LLMResponse:
        """Analyze submission quality"""
        query = f"Analyze the quality of a student submission for assignment '{assignment.name}' and provide improvement suggestions."
        return self.search_facts(query)
    
    def explain_concept(self, concept: str, context: str = "", level: str = "undergraduate") -> LLMResponse:
        """Explain academic concepts with current information"""
        query = f"Explain the concept '{concept}' at {level} level. Context: {context}"
        return self.search_facts(query)
    
    def create_study_plan(self, assignments: List[Assignment], days_ahead: int = 7) -> LLMResponse:
        """Create study plan based on assignments"""
        assignment_names = [a.name for a in assignments]
        query = f"Create a study plan for these assignments over {days_ahead} days: {', '.join(assignment_names)}"
        return self.search_facts(query)
    
    def generate_assignment_help(self, assignment: Assignment, question: str = "") -> LLMResponse:
        """Generate help for assignments"""
        query = f"Provide help and guidance for assignment '{assignment.name}'. Student question: {question}"
        return self.search_facts(query)
    
    def generate_feedback_draft(self, assignment: Assignment, submission: Submission, 
                               feedback_type: str = "constructive") -> LLMResponse:
        """Generate feedback draft"""
        query = f"Generate {feedback_type} feedback for a student submission on assignment '{assignment.name}'"
        return self.search_facts(query)


# Factory function
def create_llm_adapter(provider: LLMProvider, **kwargs) -> LLMAdapter:
    """Factory function to create LLM adapters"""
    
    if provider == LLMProvider.GROQ:
        return GroqAdapter(
            api_key=kwargs.get('api_key', os.getenv('GROQ_API_KEY')),
            model=kwargs.get('model', 'llama-3.1-8b-instant')
        )
    elif provider == LLMProvider.PERPLEXITY:
        return PerplexityAdapter(
            api_key=kwargs.get('api_key', os.getenv('PERPLEXITY_API_KEY'))
        )
    elif provider == LLMProvider.OPENAI:
        # TODO: Implement OpenAI adapter
        raise NotImplementedError("OpenAI adapter not yet implemented")
    elif provider == LLMProvider.OLLAMA:
        # TODO: Implement Ollama adapter
        raise NotImplementedError("Ollama adapter not yet implemented")
    else:
        raise ValueError(f"Unsupported LLM provider: {provider}")


# Example usage
if __name__ == "__main__":
    from dotenv import load_dotenv
    load_dotenv()
    
    # Create Groq adapter
    adapter = create_llm_adapter(
        LLMProvider.GROQ,
        api_key=os.getenv('GROQ_API_KEY')
    )
    
    service = LLMService(adapter)
    
    # Test feedback generation
    print("✅ LLM service initialized")
    print(f"Using model: {adapter.model}")
