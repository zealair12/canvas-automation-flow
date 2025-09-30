"""
Main application entry point for Canvas automation system
Coordinates all services and provides CLI interface
"""

import os
import sys
import argparse
import logging
from datetime import datetime, timedelta
from typing import Optional

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

# Load environment variables from .env file
from dotenv import load_dotenv
from pathlib import Path

# Load environment variables from .env file
load_dotenv(dotenv_path=Path(__file__).resolve().parent.parent / ".env", override=False)

from auth.auth_service import CanvasAuthService, TokenManager
from canvas.canvas_client import CanvasAPIClient
from llm.llm_service import LLMService, create_llm_adapter, LLMProvider
from notifications.notification_service import NotificationService
from sync.sync_service import CanvasSyncService
from models.data_models import DatabaseInterface
from tests.test_suite import run_tests


class InMemoryDatabase(DatabaseInterface):
    """Simple in-memory database implementation for development"""
    
    def __init__(self):
        self.courses = {}
        self.assignments = {}
        self.submissions = {}
        self.reminders = {}
        self.feedback_drafts = {}
    
    def save_course(self, course) -> bool:
        self.courses[course.id] = course
        return True
    
    def get_course(self, course_id: str):
        return self.courses.get(course_id)
    
    def get_courses_for_user(self, user_id: str):
        return list(self.courses.values())
    
    def save_assignment(self, assignment) -> bool:
        self.assignments[assignment.id] = assignment
        return True
    
    def get_assignment(self, assignment_id: str):
        return self.assignments.get(assignment_id)
    
    def get_assignments_for_course(self, course_id: str):
        return [a for a in self.assignments.values() if a.course_id == course_id]
    
    def save_submission(self, submission) -> bool:
        self.submissions[submission.id] = submission
        return True
    
    def get_submission(self, submission_id: str):
        return self.submissions.get(submission_id)
    
    def get_submissions_for_assignment(self, assignment_id: str):
        return [s for s in self.submissions.values() if s.assignment_id == assignment_id]
    
    def save_reminder(self, reminder) -> bool:
        self.reminders[reminder.id] = reminder
        return True
    
    def get_pending_reminders(self):
        return [r for r in self.reminders.values() if r.status.value == 'pending']
    
    def save_feedback_draft(self, feedback) -> bool:
        self.feedback_drafts[feedback.id] = feedback
        return True
    
    def get_feedback_draft(self, feedback_id: str):
        return self.feedback_drafts.get(feedback_id)


class CanvasAutomationApp:
    """Main application class"""
    
    def __init__(self):
        self.setup_logging()
        self.setup_services()
    
    def setup_logging(self):
        """Setup logging configuration"""
        log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
        logging.basicConfig(
            level=getattr(logging, log_level),
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.StreamHandler(),
                logging.FileHandler('canvas_automation.log')
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def setup_services(self):
        """Initialize all services"""
        try:
            # Token manager
            self.token_manager = TokenManager(os.getenv('ENCRYPTION_KEY'))
            
            # Auth service
            canvas_base_url = os.getenv('CANVAS_BASE_URL')
            if not canvas_base_url:
                raise ValueError("CANVAS_BASE_URL environment variable is required")
            
            self.auth_service = CanvasAuthService(
                canvas_base_url=canvas_base_url,
                client_id=os.getenv('CANVAS_CLIENT_ID', ''),
                client_secret=os.getenv('CANVAS_CLIENT_SECRET', ''),
                redirect_uri=os.getenv('CANVAS_REDIRECT_URI', 'http://localhost:8000/auth/callback'),
                token_manager=self.token_manager
            )
            
            # Database
            self.database = InMemoryDatabase()
            
            # Sync service
            self.sync_service = CanvasSyncService(self.auth_service, self.database)
            
            # LLM service with dual API support
            groq_api_key = os.getenv('GROQ_API_KEY')
            perplexity_api_key = os.getenv('PERPLEXITY_API_KEY')
            
            if groq_api_key or perplexity_api_key:
                # Create GROQ adapter for calculations
                groq_adapter = None
                if groq_api_key:
                    groq_adapter = create_llm_adapter(LLMProvider.GROQ, api_key=groq_api_key)
                
                # Create Perplexity adapter for factual research
                perplexity_adapter = None
                if perplexity_api_key:
                    perplexity_adapter = create_llm_adapter(LLMProvider.PERPLEXITY, api_key=perplexity_api_key)
                
                self.llm_service = LLMService(
                    adapter=groq_adapter or perplexity_adapter,
                    perplexity_adapter=perplexity_adapter
                )
                
                if groq_api_key and perplexity_api_key:
                    self.logger.info("✅ Dual LLM setup: GROQ for calculations, Perplexity for facts")
                elif groq_api_key:
                    self.logger.info("✅ LLM setup: GROQ only")
                else:
                    self.logger.info("✅ LLM setup: Perplexity only")
            else:
                self.logger.warning("No LLM API keys set - LLM features will be disabled")
                self.llm_service = None
            
            # Notification service
            self.notification_service = NotificationService()
            
            self.logger.info("✅ All services initialized successfully")
            
        except Exception as e:
            self.logger.error(f"❌ Failed to initialize services: {e}")
            raise
    
    def test_connection(self, user_id: Optional[str] = None) -> bool:
        """Test Canvas connection"""
        try:
            if user_id:
                user = self.auth_service.get_user(user_id)
                if not user:
                    self.logger.error(f"User {user_id} not found")
                    return False
                
                client = CanvasAPIClient(
                    base_url=os.getenv('CANVAS_BASE_URL'),
                    access_token=self.token_manager.decrypt_token(user.access_token)
                )
                user_info = client.get_user_info()
                self.logger.info(f"✅ Connected as: {user_info.get('name', 'Unknown')}")
            else:
                # Test with environment token
                client = CanvasAPIClient(
                    base_url=os.getenv('CANVAS_BASE_URL'),
                    access_token=os.getenv('CANVAS_ACCESS_TOKEN')
                )
                user_info = client.get_user_info()
                self.logger.info(f"✅ Connected as: {user_info.get('name', 'Unknown')}")
            
            return True
            
        except Exception as e:
            self.logger.error(f"❌ Connection test failed: {e}")
            return False
    
    def sync_user_data(self, user_id: str, sync_type: str = 'courses') -> bool:
        """Sync user data from Canvas"""
        try:
            self.logger.info(f"Starting {sync_type} sync for user {user_id}")
            job_id = self.sync_service.trigger_sync(user_id, sync_type)
            
            if job_id:
                self.logger.info(f"Sync job started: {job_id}")
                return True
            else:
                self.logger.error("Failed to start sync job")
                return False
                
        except Exception as e:
            self.logger.error(f"Sync failed: {e}")
            return False
    
    def generate_reminder(self, user_id: str, assignment_id: str, hours_before: int = 24) -> bool:
        """Generate reminder for assignment"""
        try:
            # Get user and assignment
            user = self.auth_service.get_user(user_id)
            assignment = self.database.get_assignment(assignment_id)
            
            if not user or not assignment:
                self.logger.error("User or assignment not found")
                return False
            
            # Generate reminder message
            message = self.llm_service.create_reminder_message(assignment, user, hours_before)
            
            # Create reminder
            from src.models.data_models import Reminder, ReminderStatus
            reminder = Reminder(
                id=f"reminder_{user_id}_{assignment_id}_{datetime.utcnow().timestamp()}",
                user_id=user_id,
                assignment_id=assignment_id,
                message=message,
                scheduled_for=assignment.due_at - timedelta(hours=hours_before) if assignment.due_at else datetime.utcnow()
            )
            
            self.database.save_reminder(reminder)
            self.logger.info(f"✅ Reminder created: {reminder.id}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to generate reminder: {e}")
            return False
    
    def run_tests(self) -> bool:
        """Run test suite"""
        try:
            self.logger.info("Running test suite...")
            success = run_tests()
            
            if success:
                self.logger.info("✅ All tests passed!")
            else:
                self.logger.error("❌ Some tests failed!")
            
            return success
            
        except Exception as e:
            self.logger.error(f"Test execution failed: {e}")
            return False
    
    def start_api_server(self, host: str = '0.0.0.0', port: int = 5000):
        """Start the API server"""
        try:
            from src.api.app import app
            
            self.logger.info(f"Starting API server on {host}:{port}")
            app.run(host=host, port=port, debug=False)
            
        except Exception as e:
            self.logger.error(f"Failed to start API server: {e}")
            raise


def main():
    """Main CLI entry point"""
    parser = argparse.ArgumentParser(description='Canvas Automation System')
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Test connection command
    test_parser = subparsers.add_parser('test', help='Test Canvas connection')
    test_parser.add_argument('--user-id', help='User ID to test with')
    
    # Sync command
    sync_parser = subparsers.add_parser('sync', help='Sync Canvas data')
    sync_parser.add_argument('user_id', help='User ID to sync')
    sync_parser.add_argument('--type', choices=['courses', 'assignments', 'full'], 
                            default='courses', help='Sync type')
    
    # Reminder command
    reminder_parser = subparsers.add_parser('reminder', help='Generate reminder')
    reminder_parser.add_argument('user_id', help='User ID')
    reminder_parser.add_argument('assignment_id', help='Assignment ID')
    reminder_parser.add_argument('--hours', type=int, default=24, help='Hours before due')
    
    # Test suite command
    subparsers.add_parser('test-suite', help='Run test suite')
    
    # API server command
    api_parser = subparsers.add_parser('api', help='Start API server')
    api_parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    api_parser.add_argument('--port', type=int, default=5000, help='Port to bind to')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    # Initialize app
    try:
        app = CanvasAutomationApp()
    except Exception as e:
        print(f"❌ Failed to initialize application: {e}")
        return 1
    
    # Execute command
    try:
        if args.command == 'test':
            success = app.test_connection(args.user_id)
            return 0 if success else 1
            
        elif args.command == 'sync':
            success = app.sync_user_data(args.user_id, args.type)
            return 0 if success else 1
            
        elif args.command == 'reminder':
            success = app.generate_reminder(args.user_id, args.assignment_id, args.hours)
            return 0 if success else 1
            
        elif args.command == 'test-suite':
            success = app.run_tests()
            return 0 if success else 1
            
        elif args.command == 'api':
            app.start_api_server(args.host, args.port)
            return 0
            
    except KeyboardInterrupt:
        print("\n👋 Shutting down...")
        return 0
    except Exception as e:
        print(f"❌ Command failed: {e}")
        return 1


if __name__ == '__main__':
    exit(main())
