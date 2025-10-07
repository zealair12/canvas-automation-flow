"""
Quiz Service for Canvas API
Handles quiz operations including fetching quizzes, submissions, questions, and answers
"""

import os
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
from src.canvas.canvas_client import CanvasAPIClient, CanvasAPIError
from src.models.data_models import Quiz, QuizQuestion, QuizSubmission, QuizType, QuestionType

logger = logging.getLogger(__name__)


class CanvasQuizService:
    """Service for managing Canvas quizzes"""
    
    def __init__(self, base_url: str, access_token: str):
        """
        Initialize quiz service
        
        Args:
            base_url: Canvas instance base URL
            access_token: Canvas API access token
        """
        self.client = CanvasAPIClient(base_url, access_token)
        self.base_url = base_url
        self.access_token = access_token
    
    def get_course_quizzes(self, course_id: str) -> List[Quiz]:
        """
        Get all quizzes for a course
        
        Args:
            course_id: Canvas course ID
            
        Returns:
            List of Quiz objects
        """
        try:
            endpoint = f"courses/{course_id}/quizzes"
            quizzes_data = self.client._make_request("GET", endpoint)
            
            quizzes = []
            for quiz_data in quizzes_data:
                quiz = self._quiz_from_canvas_data(quiz_data, course_id)
                quizzes.append(quiz)
            
            logger.info(f"Retrieved {len(quizzes)} quizzes for course {course_id}")
            return quizzes
            
        except CanvasAPIError as e:
            logger.error(f"Error fetching quizzes for course {course_id}: {e}")
            raise
    
    def get_quiz(self, course_id: str, quiz_id: str) -> Optional[Quiz]:
        """
        Get a specific quiz
        
        Args:
            course_id: Canvas course ID
            quiz_id: Canvas quiz ID
            
        Returns:
            Quiz object or None if not found
        """
        try:
            endpoint = f"courses/{course_id}/quizzes/{quiz_id}"
            quiz_data = self.client._make_request("GET", endpoint)
            
            if quiz_data:
                return self._quiz_from_canvas_data(quiz_data, course_id)
            
            return None
            
        except CanvasAPIError as e:
            logger.error(f"Error fetching quiz {quiz_id}: {e}")
            return None
    
    def start_quiz_attempt(self, course_id: str, quiz_id: str) -> Optional[Dict[str, Any]]:
        """
        Start a new quiz attempt
        
        Args:
            course_id: Canvas course ID
            quiz_id: Canvas quiz ID
            
        Returns:
            Quiz submission data with validation token
        """
        try:
            endpoint = f"courses/{course_id}/quizzes/{quiz_id}/submissions"
            submission_data = self.client._make_request("POST", endpoint)
            
            logger.info(f"Started quiz attempt for quiz {quiz_id}")
            return submission_data
            
        except CanvasAPIError as e:
            logger.error(f"Error starting quiz attempt for quiz {quiz_id}: {e}")
            raise
    
    def get_quiz_submission(self, course_id: str, quiz_id: str, submission_id: str) -> Optional[QuizSubmission]:
        """
        Get a quiz submission
        
        Args:
            course_id: Canvas course ID
            quiz_id: Canvas quiz ID
            submission_id: Canvas submission ID
            
        Returns:
            QuizSubmission object or None
        """
        try:
            endpoint = f"courses/{course_id}/quizzes/{quiz_id}/submissions/{submission_id}"
            submission_data = self.client._make_request("GET", endpoint)
            
            if submission_data:
                return self._submission_from_canvas_data(submission_data, quiz_id)
            
            return None
            
        except CanvasAPIError as e:
            logger.error(f"Error fetching quiz submission {submission_id}: {e}")
            return None
    
    def get_quiz_questions(self, quiz_submission_id: str) -> List[QuizQuestion]:
        """
        Get questions for an active quiz submission
        NOTE: This only works during an active attempt with valid validation token
        
        Args:
            quiz_submission_id: Canvas quiz submission ID
            
        Returns:
            List of QuizQuestion objects
        """
        try:
            endpoint = f"quiz_submissions/{quiz_submission_id}/questions"
            questions_data = self.client._make_request("GET", endpoint)
            
            questions = []
            for q_data in questions_data.get('quiz_submission_questions', []):
                question = self._question_from_canvas_data(q_data)
                questions.append(question)
            
            logger.info(f"Retrieved {len(questions)} questions for submission {quiz_submission_id}")
            return questions
            
        except CanvasAPIError as e:
            logger.error(f"Error fetching quiz questions: {e}")
            raise
    
    def answer_question(self, quiz_submission_id: str, question_id: str, answer: Any, validation_token: str) -> bool:
        """
        Submit an answer to a quiz question
        
        Args:
            quiz_submission_id: Canvas quiz submission ID
            question_id: Canvas question ID
            answer: Answer data (format depends on question type)
            validation_token: Validation token from quiz submission
            
        Returns:
            True if successful
        """
        try:
            endpoint = f"quiz_submissions/{quiz_submission_id}/questions"
            
            data = {
                'validation_token': validation_token,
                'quiz_questions': [{
                    'id': question_id,
                    'answer': answer
                }]
            }
            
            self.client._make_request("PUT", endpoint, json=data)
            logger.info(f"Answered question {question_id} in submission {quiz_submission_id}")
            return True
            
        except CanvasAPIError as e:
            logger.error(f"Error answering question {question_id}: {e}")
            return False
    
    def complete_quiz_submission(self, course_id: str, quiz_id: str, submission_id: str, validation_token: str) -> bool:
        """
        Complete and submit a quiz
        
        Args:
            course_id: Canvas course ID
            quiz_id: Canvas quiz ID
            submission_id: Canvas submission ID
            validation_token: Validation token from quiz submission
            
        Returns:
            True if successful
        """
        try:
            endpoint = f"courses/{course_id}/quizzes/{quiz_id}/submissions/{submission_id}/complete"
            
            data = {
                'validation_token': validation_token,
                'attempt': 1  # Will be updated based on actual attempt number
            }
            
            self.client._make_request("POST", endpoint, json=data)
            logger.info(f"Completed quiz submission {submission_id}")
            return True
            
        except CanvasAPIError as e:
            logger.error(f"Error completing quiz submission {submission_id}: {e}")
            return False
    
    def get_submission_time_remaining(self, course_id: str, quiz_id: str, submission_id: str) -> Optional[Dict[str, Any]]:
        """
        Get time remaining for a timed quiz
        
        Args:
            course_id: Canvas course ID
            quiz_id: Canvas quiz ID
            submission_id: Canvas submission ID
            
        Returns:
            Dict with time_left, end_at, etc.
        """
        try:
            endpoint = f"courses/{course_id}/quizzes/{quiz_id}/submissions/{submission_id}/time"
            time_data = self.client._make_request("GET", endpoint)
            
            return time_data
            
        except CanvasAPIError as e:
            logger.error(f"Error fetching time remaining: {e}")
            return None
    
    def _quiz_from_canvas_data(self, data: Dict[str, Any], course_id: str) -> Quiz:
        """Convert Canvas API quiz data to Quiz object"""
        
        # Parse quiz type
        quiz_type_str = data.get('quiz_type', 'assignment')
        try:
            quiz_type = QuizType(quiz_type_str)
        except ValueError:
            quiz_type = QuizType.ASSIGNMENT
        
        # Parse dates
        due_at = None
        if data.get('due_at'):
            due_at = datetime.fromisoformat(data['due_at'].replace('Z', '+00:00'))
        
        lock_at = None
        if data.get('lock_at'):
            lock_at = datetime.fromisoformat(data['lock_at'].replace('Z', '+00:00'))
        
        unlock_at = None
        if data.get('unlock_at'):
            unlock_at = datetime.fromisoformat(data['unlock_at'].replace('Z', '+00:00'))
        
        return Quiz(
            id=f"quiz_{data['id']}",
            canvas_quiz_id=str(data['id']),
            course_id=str(course_id),
            title=data.get('title', 'Untitled Quiz'),
            description=data.get('description'),
            quiz_type=quiz_type,
            time_limit=data.get('time_limit'),
            shuffle_answers=data.get('shuffle_answers', False),
            show_correct_answers=data.get('show_correct_answers', True),
            scoring_policy=data.get('scoring_policy', 'keep_highest'),
            allowed_attempts=data.get('allowed_attempts', 1),
            one_question_at_a_time=data.get('one_question_at_a_time', False),
            cant_go_back=data.get('cant_go_back', False),
            access_code=data.get('access_code'),
            ip_filter=data.get('ip_filter'),
            due_at=due_at,
            lock_at=lock_at,
            unlock_at=unlock_at,
            published=data.get('published', False),
            points_possible=data.get('points_possible'),
            question_count=data.get('question_count', 0)
        )
    
    def _question_from_canvas_data(self, data: Dict[str, Any]) -> QuizQuestion:
        """Convert Canvas API question data to QuizQuestion object"""
        
        # Parse question type
        q_type_str = data.get('question_type', 'multiple_choice_question')
        try:
            q_type = QuestionType(q_type_str)
        except ValueError:
            q_type = QuestionType.MULTIPLE_CHOICE
        
        return QuizQuestion(
            id=f"question_{data['id']}",
            canvas_question_id=str(data['id']),
            quiz_id=str(data.get('quiz_id', '')),
            question_name=data.get('question_name', ''),
            question_text=data.get('question_text', ''),
            question_type=q_type,
            position=data.get('position', 0),
            points_possible=data.get('points_possible', 0),
            answers=data.get('answers', []),
            correct_comments=data.get('correct_comments'),
            incorrect_comments=data.get('incorrect_comments'),
            neutral_comments=data.get('neutral_comments')
        )
    
    def _submission_from_canvas_data(self, data: Dict[str, Any], quiz_id: str) -> QuizSubmission:
        """Convert Canvas API submission data to QuizSubmission object"""
        
        # Parse dates
        started_at = None
        if data.get('started_at'):
            started_at = datetime.fromisoformat(data['started_at'].replace('Z', '+00:00'))
        
        finished_at = None
        if data.get('finished_at'):
            finished_at = datetime.fromisoformat(data['finished_at'].replace('Z', '+00:00'))
        
        end_at = None
        if data.get('end_at'):
            end_at = datetime.fromisoformat(data['end_at'].replace('Z', '+00:00'))
        
        return QuizSubmission(
            id=f"quiz_submission_{data['id']}",
            canvas_submission_id=str(data['id']),
            quiz_id=str(quiz_id),
            user_id=str(data.get('user_id', '')),
            attempt=data.get('attempt', 1),
            workflow_state=data.get('workflow_state', 'untaken'),
            started_at=started_at,
            finished_at=finished_at,
            end_at=end_at,
            time_spent=data.get('time_spent', 0),
            score=data.get('score'),
            kept_score=data.get('kept_score'),
            score_before_regrade=data.get('score_before_regrade'),
            fudge_points=data.get('fudge_points', 0.0),
            has_seen_results=data.get('has_seen_results', False),
            validation_token=data.get('validation_token')
        )
