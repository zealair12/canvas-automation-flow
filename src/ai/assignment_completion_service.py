"""
AI-Powered Assignment Completion Service
Uses AI to complete assignments, with citation support from Perplexity
"""

import logging
import os
from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime
from src.models.data_models import Assignment
from src.llm.llm_service import LLMService, LLMResponse
from src.formatting.formatting_service import formatting_service, FormattingOptions

logger = logging.getLogger(__name__)


class AssignmentCompletionService:
    """Service for AI-powered assignment completion"""
    
    def __init__(self, llm_service: LLMService):
        self.llm_service = llm_service
        self.logger = logging.getLogger(__name__)
    
    def complete_assignment(self, assignment: Assignment, 
                           context_files: List[Dict[str, Any]] = None,
                           additional_context: str = "",
                           use_citations: bool = True) -> LLMResponse:
        """
        Complete an assignment using AI
        
        Args:
            assignment: Assignment object with details
            context_files: List of files to use as context
            additional_context: Additional text context
            use_citations: Whether to include research citations (uses Perplexity)
            
        Returns:
            LLMResponse with completed assignment and sources
        """
        try:
            # Build comprehensive prompt
            prompt = self._build_completion_prompt(
                assignment, 
                context_files, 
                additional_context
            )
            
            # Use Perplexity if citations are requested
            if use_citations and self.llm_service.perplexity_adapter:
                self.logger.info("Using Perplexity for assignment completion with citations")
                response = self.llm_service.perplexity_adapter.search_facts(prompt, max_results=20)
                
                # Format response with proper citations
                formatted_content = formatting_service.format_ai_response(
                    response.content,
                    sources=response.sources,
                    options=FormattingOptions(
                        include_tables=True,
                        include_math=True,
                        include_sources=True,
                        table_style="markdown",
                        citation_style="inline"
                    )
                )
                
                return LLMResponse(
                    content=formatted_content,
                    model=response.model,
                    sources=response.sources,
                    metadata={
                        "assignment_id": assignment.id,
                        "completion_type": "full_with_citations",
                        "timestamp": datetime.utcnow().isoformat()
                    }
                )
            else:
                # Use GROQ for basic completion
                self.logger.info("Using GROQ for assignment completion")
                messages = [
                    {"role": "system", "content": self.llm_service.adapter.default_system_prompt},
                    {"role": "user", "content": prompt}
                ]
                
                response = self.llm_service.adapter._make_request(
                    messages, 
                    temperature=0.3, 
                    max_tokens=2000
                )
                
                # Format response
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
                    model=response.model,
                    metadata={
                        "assignment_id": assignment.id,
                        "completion_type": "full",
                        "timestamp": datetime.utcnow().isoformat()
                    }
                )
                
        except Exception as e:
            self.logger.error(f"Error completing assignment: {e}")
            return LLMResponse(
                content=f"Unable to complete assignment: {str(e)}",
                model="error",
                metadata={"error": str(e)}
            )
    
    def complete_quiz(self, quiz: Dict[str, Any], 
                     questions: List[Dict[str, Any]],
                     use_research: bool = True) -> Dict[str, Any]:
        """
        Complete a quiz using AI
        
        Args:
            quiz: Quiz details dictionary
            questions: List of quiz questions
            use_research: Whether to use Perplexity for research
            
        Returns:
            Dictionary mapping question IDs to answers
        """
        try:
            answers = {}
            
            for question in questions:
                answer = self._answer_quiz_question(question, use_research)
                answers[question['id']] = answer
            
            return {
                "answers": answers,
                "quiz_id": quiz.get('id'),
                "completion_time": datetime.utcnow().isoformat(),
                "total_questions": len(questions)
            }
            
        except Exception as e:
            self.logger.error(f"Error completing quiz: {e}")
            return {"error": str(e)}
    
    def _answer_quiz_question(self, question: Dict[str, Any], 
                             use_research: bool = True) -> Any:
        """
        Answer a single quiz question using AI
        
        Args:
            question: Question dictionary
            use_research: Whether to use research for the answer
            
        Returns:
            Answer in appropriate format for question type
        """
        question_type = question.get('question_type')
        question_text = question.get('question_text', '')
        
        # Build research query
        query = f"""
Answer this quiz question:

**Question:** {question_text}
**Type:** {question_type}

"""
        
        # Add choices for multiple choice/answer questions
        if question_type in ['multiple_choice_question', 'multiple_answers_question']:
            answers = question.get('answers', [])
            query += "\n**Options:**\n"
            for answer in answers:
                query += f"- {answer.get('text', '')}\n"
        
        query += """
Provide the correct answer with reasoning. For multiple choice, specify the correct option.
"""
        
        # Get answer from AI
        if use_research and self.llm_service.perplexity_adapter:
            response = self.llm_service.perplexity_adapter.search_facts(query)
        else:
            messages = [
                {"role": "system", "content": "You are an expert academic assistant. Provide accurate, well-reasoned answers to quiz questions."},
                {"role": "user", "content": query}
            ]
            response = self.llm_service.adapter._make_request(messages, temperature=0.1, max_tokens=500)
        
        # Parse answer based on question type
        return self._parse_answer_for_type(question_type, response.content, question)
    
    def _parse_answer_for_type(self, question_type: str, ai_response: str, 
                               question: Dict[str, Any]) -> Any:
        """
        Parse AI response into appropriate answer format for question type
        
        Args:
            question_type: Type of question
            ai_response: AI's response text
            question: Full question dictionary
            
        Returns:
            Formatted answer for Canvas API
        """
        if question_type == 'multiple_choice_question':
            # Find the answer ID mentioned in response
            answers = question.get('answers', [])
            for answer in answers:
                answer_text = answer.get('text', '').lower()
                if answer_text in ai_response.lower():
                    return answer.get('id')
            # Default to first answer if no match
            return answers[0].get('id') if answers else None
        
        elif question_type == 'multiple_answers_question':
            # Find all answer IDs mentioned in response
            answers = question.get('answers', [])
            selected_ids = []
            for answer in answers:
                answer_text = answer.get('text', '').lower()
                if answer_text in ai_response.lower():
                    selected_ids.append(answer.get('id'))
            return selected_ids
        
        elif question_type == 'true_false_question':
            # Look for true/false in response
            response_lower = ai_response.lower()
            if 'true' in response_lower and 'false' not in response_lower:
                return True
            elif 'false' in response_lower:
                return False
            return None
        
        elif question_type in ['short_answer_question', 'essay_question']:
            # Return the AI response as-is for text answers
            return ai_response.strip()
        
        elif question_type == 'numerical_question':
            # Extract number from response
            import re
            numbers = re.findall(r'-?\d+\.?\d*', ai_response)
            return float(numbers[0]) if numbers else None
        
        elif question_type == 'fill_in_multiple_blanks_question':
            # Parse blanks from response
            # Format: {"blank_id": "answer"}
            # This is complex and may need more sophisticated parsing
            return {"answer": ai_response.strip()}
        
        else:
            # Default: return response as-is
            return ai_response.strip()
    
    def _build_completion_prompt(self, assignment: Assignment,
                                context_files: List[Dict[str, Any]] = None,
                                additional_context: str = "") -> str:
        """Build comprehensive prompt for assignment completion"""
        
        prompt = f"""
Complete this assignment with comprehensive, well-researched content:

**Assignment: {assignment.name}**

**Description:**
{assignment.description or 'No description provided'}

**Requirements:**
- Points Possible: {assignment.points_possible}
- Due Date: {assignment.due_at or 'No due date'}
- Submission Types: {', '.join(assignment.submission_types)}
"""
        
        if context_files:
            prompt += "\n\n**Context Files Provided:**\n"
            for file in context_files:
                prompt += f"- {file.get('display_name', 'Unknown')}: {file.get('description', '')}\n"
        
        if additional_context:
            prompt += f"\n\n**Additional Context:**\n{additional_context}\n"
        
        prompt += """

**Instructions:**
1. Provide a complete, well-structured response
2. Include relevant research and citations
3. Use proper formatting (Markdown, LaTeX for math)
4. Ensure academic quality and accuracy
5. Structure content logically with clear sections
6. Include examples and explanations where appropriate
7. Cite all sources using inline citations [1], [2], etc.

**Formatting Requirements:**
- Use Markdown: **bold**, *italic*, ## headers, - bullets
- Use LaTeX for math: $\\\\sqrt{x}$ (inline), $$E=mc^2$$ (display)
- Use tables where appropriate
- Include diagrams/charts descriptions if relevant

Provide the complete assignment submission:
"""
        
        return prompt


# Example usage
if __name__ == "__main__":
    from dotenv import load_dotenv
    from src.llm.llm_service import LLMService, create_llm_adapter, LLMProvider
    
    load_dotenv()
    
    # Initialize services
    groq_adapter = create_llm_adapter(LLMProvider.GROQ, api_key=os.getenv('GROQ_API_KEY'))
    perplexity_adapter = create_llm_adapter(LLMProvider.PERPLEXITY, api_key=os.getenv('PERPLEXITY_API_KEY'))
    
    llm_service = LLMService(groq_adapter, perplexity_adapter)
    completion_service = AssignmentCompletionService(llm_service)
    
    print("✅ Assignment Completion Service initialized")

