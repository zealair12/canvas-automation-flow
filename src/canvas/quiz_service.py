"""
Canvas Quiz/Exam Service
Provides access to quizzes, exams, and their questions via Canvas API
"""

import logging
from typing import Dict, Any, List, Optional
from datetime import datetime
from src.canvas.canvas_client import CanvasAPIClient

logger = logging.getLogger(__name__)


class CanvasQuizService:
    """Service for accessing Canvas quizzes and exams"""
    
    def __init__(self, base_url: str, access_token: str):
        self.client = CanvasAPIClient(base_url, access_token)
        self.logger = logging.getLogger(__name__)
    
    def get_course_quizzes(self, course_id: str) -> List[Dict[str, Any]]:
        """
        Get all quizzes for a course
        
        Args:
            course_id: Canvas course ID
            
        Returns:
            List of quiz dictionaries
        """
        try:
            response = self.client._make_request('GET', f'courses/{course_id}/quizzes')
            quizzes = response.json()
            
            self.logger.info(f"Retrieved {len(quizzes)} quizzes for course {course_id}")
            return quizzes
            
        except Exception as e:
            self.logger.error(f"Error retrieving quizzes for course {course_id}: {e}")
            return []
    
    def get_quiz_details(self, course_id: str, quiz_id: str) -> Optional[Dict[str, Any]]:
        """
        Get detailed information about a specific quiz
        
        Args:
            course_id: Canvas course ID
            quiz_id: Canvas quiz ID
            
        Returns:
            Quiz details dictionary or None
        """
        try:
            response = self.client._make_request('GET', f'courses/{course_id}/quizzes/{quiz_id}')
            quiz = response.json()
            
            self.logger.info(f"Retrieved quiz details for quiz {quiz_id}")
            return quiz
            
        except Exception as e:
            self.logger.error(f"Error retrieving quiz {quiz_id}: {e}")
            return None
    
    def get_quiz_questions(self, course_id: str, quiz_id: str) -> List[Dict[str, Any]]:
        """
        Get questions for a quiz
        
        Args:
            course_id: Canvas course ID
            quiz_id: Canvas quiz ID
            
        Returns:
            List of question dictionaries
        """
        try:
            questions = self.client.get_quiz_questions(course_id, quiz_id)
            self.logger.info(f"Retrieved {len(questions)} questions for quiz {quiz_id}")
            return questions
            
        except Exception as e:
            self.logger.error(f"Error retrieving quiz questions for quiz {quiz_id}: {e}")
            return []
    
    def get_quiz_submission_questions(self, quiz_submission_id: str) -> List[Dict[str, Any]]:
        """
        Get questions from a quiz submission
        
        Args:
            quiz_submission_id: Canvas quiz submission ID
            
        Returns:
            List of question dictionaries with student answers
        """
        try:
            response = self.client._make_request('GET', 
                f'quiz_submissions/{quiz_submission_id}/questions')
            questions = response.json()
            
            self.logger.info(f"Retrieved questions for quiz submission {quiz_submission_id}")
            return questions
            
        except Exception as e:
            self.logger.error(f"Error retrieving quiz submission questions: {e}")
            return []
    
    def create_quiz_submission(self, course_id: str, quiz_id: str) -> Optional[Dict[str, Any]]:
        """
        Start a quiz submission (for taking a quiz)
        
        Args:
            course_id: Canvas course ID
            quiz_id: Canvas quiz ID
            
        Returns:
            Quiz submission details or None
        """
        try:
            response = self.client._make_request('POST', 
                f'courses/{course_id}/quizzes/{quiz_id}/submissions')
            submission = response.json()
            
            self.logger.info(f"Created quiz submission for quiz {quiz_id}")
            return submission
            
        except Exception as e:
            self.logger.error(f"Error creating quiz submission: {e}")
            return None
    
    def answer_quiz_question(self, quiz_submission_id: str, quiz_id: str, 
                            attempt: int, validation_token: str,
                            question_id: int, answer) -> bool:
        """
        Answer a quiz question
        
        Args:
            quiz_submission_id: Canvas quiz submission ID
            quiz_id: Canvas quiz ID
            attempt: Attempt number
            validation_token: Validation token from quiz submission
            question_id: Question ID to answer
            answer: Answer data (format depends on question type)
            
        Returns:
            True if successful, False otherwise
        """
        try:
            data = {
                'attempt': attempt,
                'validation_token': validation_token,
                'quiz_questions': [{
                    'id': question_id,
                    'answer': answer
                }]
            }
            
            response = self.client._make_request('POST',
                f'quiz_submissions/{quiz_submission_id}/questions',
                json=data)
            
            self.logger.info(f"Answered question {question_id} for quiz submission {quiz_submission_id}")
            return True
            
        except Exception as e:
            self.logger.error(f"Error answering quiz question: {e}")
            return False
    
    def complete_quiz_submission(self, course_id: str, quiz_id: str,
                                 quiz_submission_id: str, attempt: int,
                                 validation_token: str) -> Optional[Dict[str, Any]]:
        """
        Complete and submit a quiz
        
        Args:
            course_id: Canvas course ID
            quiz_id: Canvas quiz ID
            quiz_submission_id: Canvas quiz submission ID
            attempt: Attempt number
            validation_token: Validation token from quiz submission
            
        Returns:
            Completed submission details or None
        """
        try:
            data = {
                'attempt': attempt,
                'validation_token': validation_token
            }
            
            response = self.client._make_request('POST',
                f'courses/{course_id}/quizzes/{quiz_id}/submissions/{quiz_submission_id}/complete',
                json=data)
            
            submission = response.json()
            self.logger.info(f"Completed quiz submission {quiz_submission_id}")
            return submission
            
        except Exception as e:
            self.logger.error(f"Error completing quiz submission: {e}")
            return None
    
    def is_quiz_timed(self, quiz: Dict[str, Any]) -> bool:
        """Check if a quiz is timed"""
        return quiz.get('time_limit') is not None and quiz.get('time_limit') > 0
    
    def get_quiz_time_limit(self, quiz: Dict[str, Any]) -> Optional[int]:
        """Get quiz time limit in minutes"""
        return quiz.get('time_limit')
    
    def can_take_quiz(self, quiz: Dict[str, Any]) -> bool:
        """
        Check if quiz can be taken (not locked by dates)
        
        Args:
            quiz: Quiz details dictionary
            
        Returns:
            True if quiz can be taken, False otherwise
        """
        now = datetime.now()
        
        # Check if quiz is locked
        if quiz.get('locked_for_user'):
            return False
        
        # Check unlock date
        if quiz.get('unlock_at'):
            unlock_date = datetime.fromisoformat(quiz['unlock_at'].replace('Z', '+00:00'))
            if now < unlock_date:
                return False
        
        # Check lock date
        if quiz.get('lock_at'):
            lock_date = datetime.fromisoformat(quiz['lock_at'].replace('Z', '+00:00'))
            if now > lock_date:
                return False
        
        return True


# Example usage
if __name__ == "__main__":
    import os
    from dotenv import load_dotenv
    
    load_dotenv()
    
    service = CanvasQuizService(
        base_url=os.getenv("CANVAS_BASE_URL"),
        access_token=os.getenv("CANVAS_ACCESS_TOKEN")
    )
    
    # Test getting quizzes
    course_id = "YOUR_COURSE_ID"
    quizzes = service.get_course_quizzes(course_id)
    print(f"Found {len(quizzes)} quizzes")
    
    if quizzes:
        quiz = quizzes[0]
        print(f"Quiz: {quiz.get('title')}")
        print(f"Timed: {service.is_quiz_timed(quiz)}")
        print(f"Can take: {service.can_take_quiz(quiz)}")

