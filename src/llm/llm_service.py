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
from models.data_models import Assignment, Submission, FeedbackDraft
from auth.auth_service import User


class LLMProvider(Enum):
    GROQ = "groq"
    OPENAI = "openai"
    OLLAMA = "ollama"


@dataclass
class LLMResponse:
    """Standardized LLM response"""
    content: str
    model: str
    tokens_used: Optional[int] = None
    confidence_score: Optional[float] = None
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
    
    def __init__(self, adapter: LLMAdapter):
        self.adapter = adapter
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
    
    def generate_assignment_help(self, assignment: Assignment, question: str) -> LLMResponse:
        """Generate AI help for an assignment"""
        try:
            prompt = f"""
You are an AI tutor helping a student with their assignment. 

Assignment Details:
- Name: {assignment.name}
- Description: {assignment.description or 'No description provided'}
- Points Possible: {assignment.points_possible}
- Due Date: {assignment.due_at or 'No due date'}
- Submission Types: {', '.join(assignment.submission_types)}

Student Question: {question}

Please provide helpful, educational guidance that:
1. Helps the student understand the concepts
2. Provides direction without giving direct answers
3. Encourages critical thinking
4. Is appropriate for the assignment level

Response:
"""
            
            response = self.adapter.client.chat.completions.create(
                model=self.adapter.model,
                messages=[
                    {"role": "system", "content": "You are a helpful AI tutor who guides students to learn rather than giving direct answers."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=800,
                temperature=0.7
            )
            
            return LLMResponse(
                content=response.choices[0].message.content.strip(),
                model=self.adapter.model,
                tokens_used=response.usage.total_tokens if hasattr(response, 'usage') else None
            )
        except Exception as e:
            self.logger.error(f"Error generating assignment help: {e}")
            return LLMResponse(
                content="I apologize, but I'm unable to provide help at the moment. Please try again later.",
                model=self.adapter.model
            )
    
    def create_study_plan(self, assignments: List[Assignment], days_ahead: int = 7) -> LLMResponse:
        """Create an AI-generated study plan"""
        try:
            # Filter assignments with due dates
            upcoming_assignments = []
            for assignment in assignments:
                if assignment.due_at:
                    try:
                        due_date = datetime.fromisoformat(assignment.due_at.replace('Z', '+00:00'))
                        days_until_due = (due_date - datetime.now()).days
                        if 0 <= days_until_due <= days_ahead:
                            upcoming_assignments.append((assignment, days_until_due))
                    except:
                        continue
            
            if not upcoming_assignments:
                return LLMResponse(
                    content=f"No assignments found with due dates in the next {days_ahead} days.",
                    model=self.adapter.model
                )
            
            # Sort by due date
            upcoming_assignments.sort(key=lambda x: x[1])
            
            assignment_list = ""
            for assignment, days_until in upcoming_assignments:
                assignment_list += f"- {assignment.name} (Due in {days_until} days, {assignment.points_possible} points)\n"
            
            prompt = f"""
Create a personalized study plan for the next {days_ahead} days based on these upcoming assignments:

{assignment_list}

Please provide:
1. A day-by-day breakdown
2. Time allocation suggestions
3. Priority recommendations based on due dates and point values
4. Study strategies for different types of assignments
5. Buffer time for unexpected challenges

Make the plan realistic and achievable for a student.
"""
            
            response = self.adapter.client.chat.completions.create(
                model=self.adapter.model,
                messages=[
                    {"role": "system", "content": "You are an AI academic advisor creating personalized study plans for students."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=1000,
                temperature=0.6
            )
            
            return LLMResponse(
                content=response.choices[0].message.content.strip(),
                model=self.adapter.model,
                tokens_used=response.usage.total_tokens if hasattr(response, 'usage') else None
            )
        except Exception as e:
            self.logger.error(f"Error creating study plan: {e}")
            return LLMResponse(
                content="Unable to create study plan at the moment. Please try again later.",
                model=self.adapter.model
            )
    
    def explain_concept(self, concept: str, context: str = "", level: str = "undergraduate") -> LLMResponse:
        """Explain academic concepts with AI"""
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

Your explanation should:
1. Start with a clear, simple definition
2. Provide relevant examples
3. Break down complex parts into understandable pieces
4. Connect to broader concepts when appropriate
5. Be educational and engaging{context_text}

Please provide a comprehensive but accessible explanation.
"""
            
            response = self.adapter.client.chat.completions.create(
                model=self.adapter.model,
                messages=[
                    {"role": "system", "content": f"You are an expert educator explaining concepts to {audience}. Make your explanations clear, accurate, and engaging."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=800,
                temperature=0.7
            )
            
            return LLMResponse(
                content=response.choices[0].message.content.strip(),
                model=self.adapter.model,
                tokens_used=response.usage.total_tokens if hasattr(response, 'usage') else None
            )
        except Exception as e:
            self.logger.error(f"Error explaining concept: {e}")
            return LLMResponse(
                content=f"Unable to explain '{concept}' at the moment. Please try again later.",
                model=self.adapter.model
            )
    
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
You are reviewing a student submission for the following assignment:

Assignment: {assignment.name}
Description: {assignment.description or 'No description provided'}
Points Possible: {assignment.points_possible}

Submission Content:
{submission.body or 'No content provided'}

Please provide {style} feedback that:
1. Acknowledges what the student did well
2. Identifies areas for improvement
3. Provides specific, actionable suggestions
4. Maintains a supportive tone
5. Is appropriate for the academic level

Your feedback should help the student learn and improve their work.
"""
            
            response = self.adapter.client.chat.completions.create(
                model=self.adapter.model,
                messages=[
                    {"role": "system", "content": "You are an experienced educator providing thoughtful feedback on student work."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=600,
                temperature=0.6
            )
            
            return LLMResponse(
                content=response.choices[0].message.content.strip(),
                model=self.adapter.model,
                tokens_used=response.usage.total_tokens if hasattr(response, 'usage') else None
            )
        except Exception as e:
            self.logger.error(f"Error generating feedback draft: {e}")
            return LLMResponse(
                content="Unable to generate feedback at the moment. Please try again later.",
                model=self.adapter.model
            )


# Factory function


# Factory function
def create_llm_adapter(provider: LLMProvider, **kwargs) -> LLMAdapter:
    """Factory function to create LLM adapters"""
    
    if provider == LLMProvider.GROQ:
        return GroqAdapter(
            api_key=kwargs.get('api_key', os.getenv('GROQ_API_KEY')),
            model=kwargs.get('model', 'llama-3.1-8b-instant')
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
