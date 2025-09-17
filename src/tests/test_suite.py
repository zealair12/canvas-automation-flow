"""
Testing framework with mock Canvas data
Provides comprehensive testing utilities for Canvas automation system
"""

import os
import json
import unittest
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from unittest.mock import Mock, patch, MagicMock
import tempfile
import shutil

from auth.auth_service import CanvasAuthService, TokenManager, User, UserRole
from canvas.canvas_client import CanvasAPIClient, CanvasAPIError
from models.data_models import Course, Assignment, Submission, Reminder, FeedbackDraft
from llm.llm_service import LLMService, GroqAdapter, LLMProvider
from notifications.notification_service import NotificationService, NotificationType
from sync.sync_service import CanvasSyncService


class MockCanvasData:
    """Mock Canvas API responses for testing"""
    
    @staticmethod
    def get_user_info() -> Dict[str, Any]:
        return {
            "id": 12345,
            "name": "Test Student",
            "email": "test@example.com",
            "avatar_url": "https://example.com/avatar.jpg",
            "locale": "en",
            "time_zone": "America/New_York"
        }
    
    @staticmethod
    def get_courses() -> List[Dict[str, Any]]:
        return [
            {
                "id": 1001,
                "name": "Introduction to Computer Science",
                "course_code": "CS101",
                "description": "Basic programming concepts",
                "workflow_state": "available",
                "start_at": "2024-01-15T00:00:00Z",
                "end_at": "2024-05-15T23:59:59Z",
                "enrollment_term_id": 1
            },
            {
                "id": 1002,
                "name": "Data Structures",
                "course_code": "CS201",
                "description": "Advanced data structures and algorithms",
                "workflow_state": "available",
                "start_at": "2024-01-15T00:00:00Z",
                "end_at": "2024-05-15T23:59:59Z",
                "enrollment_term_id": 1
            }
        ]
    
    @staticmethod
    def get_assignments(course_id: int) -> List[Dict[str, Any]]:
        return [
            {
                "id": 2001,
                "name": "Programming Assignment 1",
                "description": "Write a simple calculator program",
                "due_at": (datetime.utcnow() + timedelta(days=7)).isoformat() + "Z",
                "lock_at": (datetime.utcnow() + timedelta(days=7, hours=1)).isoformat() + "Z",
                "unlock_at": datetime.utcnow().isoformat() + "Z",
                "points_possible": 100.0,
                "grading_type": "points",
                "submission_types": ["online_text_entry", "online_upload"],
                "allowed_extensions": ["py", "java", "cpp"],
                "workflow_state": "published"
            },
            {
                "id": 2002,
                "name": "Midterm Exam",
                "description": "Comprehensive exam covering chapters 1-5",
                "due_at": (datetime.utcnow() + timedelta(days=14)).isoformat() + "Z",
                "points_possible": 200.0,
                "grading_type": "points",
                "submission_types": ["online_quiz"],
                "workflow_state": "published"
            }
        ]
    
    @staticmethod
    def get_submissions(course_id: int, assignment_id: int) -> List[Dict[str, Any]]:
        return [
            {
                "id": 3001,
                "assignment_id": assignment_id,
                "user_id": 12345,
                "submitted_at": (datetime.utcnow() - timedelta(days=1)).isoformat() + "Z",
                "score": 85.0,
                "grade": "B",
                "workflow_state": "submitted",
                "late": False,
                "excused": False,
                "attempt": 1,
                "body": "Here is my calculator implementation...",
                "url": None,
                "attachments": [
                    {
                        "id": 4001,
                        "filename": "calculator.py",
                        "url": "https://example.com/files/calculator.py",
                        "content_type": "text/x-python"
                    }
                ]
            },
            {
                "id": 3002,
                "assignment_id": assignment_id,
                "user_id": 12346,
                "submitted_at": None,
                "score": None,
                "grade": None,
                "workflow_state": "unsubmitted",
                "late": False,
                "excused": False,
                "attempt": 0,
                "body": None,
                "url": None,
                "attachments": []
            }
        ]


class MockDatabase:
    """Mock database implementation for testing"""
    
    def __init__(self):
        self.courses = {}
        self.assignments = {}
        self.submissions = {}
        self.reminders = {}
        self.feedback_drafts = {}
    
    def save_course(self, course: Course) -> bool:
        self.courses[course.id] = course
        return True
    
    def get_course(self, course_id: str) -> Optional[Course]:
        return self.courses.get(course_id)
    
    def get_courses_for_user(self, user_id: str) -> List[Course]:
        return list(self.courses.values())
    
    def save_assignment(self, assignment: Assignment) -> bool:
        self.assignments[assignment.id] = assignment
        return True
    
    def get_assignment(self, assignment_id: str) -> Optional[Assignment]:
        return self.assignments.get(assignment_id)
    
    def get_assignments_for_course(self, course_id: str) -> List[Assignment]:
        return [a for a in self.assignments.values() if a.course_id == course_id]
    
    def save_submission(self, submission: Submission) -> bool:
        self.submissions[submission.id] = submission
        return True
    
    def get_submission(self, submission_id: str) -> Optional[Submission]:
        return self.submissions.get(submission_id)
    
    def get_submissions_for_assignment(self, assignment_id: str) -> List[Submission]:
        return [s for s in self.submissions.values() if s.assignment_id == assignment_id]
    
    def save_reminder(self, reminder: Reminder) -> bool:
        self.reminders[reminder.id] = reminder
        return True
    
    def get_pending_reminders(self) -> List[Reminder]:
        return [r for r in self.reminders.values() if r.status.value == 'pending']
    
    def save_feedback_draft(self, feedback: FeedbackDraft) -> bool:
        self.feedback_drafts[feedback.id] = feedback
        return True
    
    def get_feedback_draft(self, feedback_id: str) -> Optional[FeedbackDraft]:
        return self.feedback_drafts.get(feedback_id)


class TestCanvasAuthService(unittest.TestCase):
    """Test cases for Canvas authentication service"""
    
    def setUp(self):
        self.token_manager = TokenManager()
        self.auth_service = CanvasAuthService(
            canvas_base_url="https://test.instructure.com",
            client_id="test_client_id",
            client_secret="test_client_secret",
            redirect_uri="http://localhost:8000/auth/callback",
            token_manager=self.token_manager
        )
    
    def test_get_authorization_url(self):
        """Test authorization URL generation"""
        auth_url = self.auth_service.get_authorization_url()
        self.assertIn("https://test.instructure.com/login/oauth2/auth", auth_url)
        self.assertIn("client_id=test_client_id", auth_url)
        self.assertIn("response_type=code", auth_url)
    
    @patch('requests.post')
    def test_exchange_code_for_token(self, mock_post):
        """Test token exchange"""
        mock_response = Mock()
        mock_response.json.return_value = {
            'access_token': 'test_access_token',
            'refresh_token': 'test_refresh_token',
            'expires_in': 3600
        }
        mock_response.raise_for_status.return_value = None
        mock_post.return_value = mock_response
        
        result = self.auth_service.exchange_code_for_token('test_code')
        self.assertIsNotNone(result)
        self.assertEqual(result['access_token'], 'test_access_token')
    
    @patch('requests.get')
    def test_get_user_info(self, mock_get):
        """Test user info retrieval"""
        mock_response = Mock()
        mock_response.json.return_value = MockCanvasData.get_user_info()
        mock_response.raise_for_status.return_value = None
        mock_get.return_value = mock_response
        
        result = self.auth_service.get_user_info('test_token')
        self.assertIsNotNone(result)
        self.assertEqual(result['name'], 'Test Student')


class TestCanvasAPIClient(unittest.TestCase):
    """Test cases for Canvas API client"""
    
    def setUp(self):
        self.client = CanvasAPIClient(
            base_url="https://test.instructure.com",
            access_token="test_token"
        )
    
    @patch('requests.get')
    def test_get_user_info(self, mock_get):
        """Test user info retrieval"""
        mock_response = Mock()
        mock_response.json.return_value = MockCanvasData.get_user_info()
        mock_response.raise_for_status.return_value = None
        mock_response.headers = {}
        mock_get.return_value = mock_response
        
        result = self.client.get_user_info()
        self.assertIsNotNone(result)
        self.assertEqual(result['name'], 'Test Student')
    
    @patch('requests.get')
    def test_get_courses(self, mock_get):
        """Test courses retrieval"""
        mock_response = Mock()
        mock_response.json.return_value = MockCanvasData.get_courses()
        mock_response.raise_for_status.return_value = None
        mock_response.headers = {}
        mock_get.return_value = mock_response
        
        result = self.client.get_courses()
        self.assertIsNotNone(result)
        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]['name'], 'Introduction to Computer Science')
    
    @patch('requests.get')
    def test_get_assignments(self, mock_get):
        """Test assignments retrieval"""
        mock_response = Mock()
        mock_response.json.return_value = MockCanvasData.get_assignments(1001)
        mock_response.raise_for_status.return_value = None
        mock_response.headers = {}
        mock_get.return_value = mock_response
        
        result = self.client.get_assignments('1001')
        self.assertIsNotNone(result)
        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]['name'], 'Programming Assignment 1')


class TestLLMService(unittest.TestCase):
    """Test cases for LLM service"""
    
    def setUp(self):
        self.mock_adapter = Mock()
        self.llm_service = LLMService(self.mock_adapter)
    
    def test_create_reminder_message(self):
        """Test reminder message generation"""
        assignment = Assignment(
            id="test_1",
            canvas_assignment_id="123",
            course_id="course_1",
            name="Test Assignment",
            due_at=datetime.utcnow() + timedelta(hours=24)
        )
        
        user = User(
            id="user_1",
            canvas_user_id="456",
            email="test@example.com",
            name="Test Student",
            role=UserRole.STUDENT,
            access_token="dummy_token"
        )
        
        self.mock_adapter.generate_reminder_message.return_value = Mock(
            content="Don't forget about Test Assignment!"
        )
        
        result = self.llm_service.create_reminder_message(assignment, user, 24)
        self.assertEqual(result, "Don't forget about Test Assignment!")
        self.mock_adapter.generate_reminder_message.assert_called_once()


class TestNotificationService(unittest.TestCase):
    """Test cases for notification service"""
    
    def setUp(self):
        self.notification_service = NotificationService()
    
    def test_send_notification(self):
        """Test notification sending"""
        # Mock providers
        mock_provider = Mock()
        mock_provider.send.return_value = True
        self.notification_service.providers[NotificationType.PUSH] = mock_provider
        
        notification_id = self.notification_service.send_notification(
            user_id="test_user",
            title="Test Notification",
            message="This is a test",
            notification_type=NotificationType.PUSH,
            metadata={'device_token': 'test_token'}
        )
        
        self.assertIsNotNone(notification_id)
        mock_provider.send.assert_called_once()


class TestSyncService(unittest.TestCase):
    """Test cases for sync service"""
    
    def setUp(self):
        self.mock_auth_service = Mock()
        self.mock_database = MockDatabase()
        self.sync_service = CanvasSyncService(self.mock_auth_service, self.mock_database)
    
    @patch('src.sync.sync_service.CanvasAPIClient')
    def test_sync_user_courses(self, mock_client_class):
        """Test course synchronization"""
        # Mock user
        mock_user = Mock()
        mock_user.id = "test_user"
        self.mock_auth_service.get_user.return_value = mock_user
        self.mock_auth_service.token_manager.decrypt_token.return_value = "test_token"
        
        # Mock Canvas client
        mock_client = Mock()
        mock_client.get_courses.return_value = MockCanvasData.get_courses()
        mock_client_class.return_value = mock_client
        
        job_id = self.sync_service.sync_user_courses("test_user")
        
        self.assertIsNotNone(job_id)
        self.assertEqual(len(self.mock_database.courses), 2)


class IntegrationTestSuite(unittest.TestCase):
    """Integration tests for the complete system"""
    
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        
        # Initialize services
        self.token_manager = TokenManager()
        self.auth_service = CanvasAuthService(
            canvas_base_url="https://test.instructure.com",
            client_id="test_client_id",
            client_secret="test_client_secret",
            redirect_uri="http://localhost:8000/auth/callback",
            token_manager=self.token_manager
        )
        
        self.database = MockDatabase()
        self.sync_service = CanvasSyncService(self.auth_service, self.database)
        
        self.notification_service = NotificationService()
    
    def tearDown(self):
        shutil.rmtree(self.temp_dir)
    
    @patch('requests.post')
    @patch('requests.get')
    def test_complete_workflow(self, mock_get, mock_post):
        """Test complete workflow from authentication to sync"""
        # Mock authentication
        mock_token_response = Mock()
        mock_token_response.json.return_value = {
            'access_token': 'test_access_token',
            'expires_in': 3600
        }
        mock_token_response.raise_for_status.return_value = None
        
        mock_user_response = Mock()
        mock_user_response.json.return_value = MockCanvasData.get_user_info()
        mock_user_response.raise_for_status.return_value = None
        
        mock_courses_response = Mock()
        mock_courses_response.json.return_value = MockCanvasData.get_courses()
        mock_courses_response.raise_for_status.return_value = None
        mock_courses_response.headers = {}
        
        mock_post.return_value = mock_token_response
        mock_get.return_value = mock_user_response
        
        # Authenticate user
        user = self.auth_service.authenticate_user('test_code')
        self.assertIsNotNone(user)
        
        # Mock Canvas client for sync
        with patch('src.sync.sync_service.CanvasAPIClient') as mock_client_class:
            mock_client = Mock()
            mock_client.get_courses.return_value = MockCanvasData.get_courses()
            mock_client_class.return_value = mock_client
            
            # Sync courses
            job_id = self.sync_service.sync_user_courses(user.id)
            self.assertIsNotNone(job_id)
            
            # Verify data was synced
            courses = self.database.get_courses_for_user(user.id)
            self.assertEqual(len(courses), 2)


def run_tests():
    """Run all test suites"""
    # Create test suite
    test_suite = unittest.TestSuite()
    
    # Add test cases
    test_suite.addTest(unittest.makeSuite(TestCanvasAuthService))
    test_suite.addTest(unittest.makeSuite(TestCanvasAPIClient))
    test_suite.addTest(unittest.makeSuite(TestLLMService))
    test_suite.addTest(unittest.makeSuite(TestNotificationService))
    test_suite.addTest(unittest.makeSuite(TestSyncService))
    test_suite.addTest(unittest.makeSuite(IntegrationTestSuite))
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(test_suite)
    
    return result.wasSuccessful()


if __name__ == '__main__':
    success = run_tests()
    if success:
        print("✅ All tests passed!")
    else:
        print("❌ Some tests failed!")
        exit(1)
