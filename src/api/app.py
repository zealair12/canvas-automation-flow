"""
Backend API endpoints for Canvas automation system
Provides REST API for mobile app, n8n workflows, and other integrations
"""

import os
import json
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List
from flask import Flask, request, jsonify, g
from flask_cors import CORS
import logging
from functools import wraps

from src.auth.auth_service import CanvasAuthService, TokenManager, User, UserRole
from src.canvas.canvas_client import CanvasAPIClient, CanvasAPIError
from src.canvas.file_upload_service import CanvasFileUploadService
from src.canvas.assignment_submission_service import CanvasAssignmentSubmissionService
from src.canvas.study_plan_service import EnhancedStudyPlanService
from src.models.data_models import Course, Assignment, Submission, Reminder, FeedbackDraft, AssignmentStatus, File
from src.llm.llm_service import LLMService, create_llm_adapter, LLMProvider
from src.api.course_consistency import CourseConsistencyChecker
from src.calendar.calendar_service import CalendarService
from src.canvas.quiz_service import CanvasQuizService
from src.ai.assignment_completion_service import AssignmentCompletionService
from src.document.document_generation_service import DocumentGenerationService


# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Configuration
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'dev-secret-key')
app.config['JSON_SORT_KEYS'] = False

# Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global services (in production, use dependency injection)
token_manager = TokenManager(os.getenv('ENCRYPTION_KEY'))
course_consistency_checker = CourseConsistencyChecker()

# Initialize auth service with validation
canvas_base_url = os.getenv('CANVAS_BASE_URL')
if not canvas_base_url:
    raise ValueError("CANVAS_BASE_URL environment variable is required")

auth_service = CanvasAuthService(
    canvas_base_url=canvas_base_url,
    client_id=os.getenv('CANVAS_CLIENT_ID', ''),
    client_secret=os.getenv('CANVAS_CLIENT_SECRET', ''),
    redirect_uri=os.getenv('CANVAS_REDIRECT_URI', 'http://localhost:8000/auth/callback'),
    token_manager=token_manager
)

# Initialize LLM service with dual API support
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
    
    llm_service = LLMService(
        adapter=groq_adapter or perplexity_adapter,
        perplexity_adapter=perplexity_adapter
    )
    
    if groq_api_key and perplexity_api_key:
        logger.info("✅ Dual LLM setup: GROQ for calculations, Perplexity for facts")
    elif groq_api_key:
        logger.info("✅ LLM setup: GROQ only")
    else:
        logger.info("✅ LLM setup: Perplexity only")
else:
    logger.warning("No LLM API keys set - LLM features will be disabled")
    llm_service = None


def require_auth(f):
    """Decorator to require authentication"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Missing or invalid authorization header'}), 401
        
        token = auth_header.split(' ')[1]
        
        # Store the Canvas token for use in the endpoint
        g.canvas_token = token
        return f(*args, **kwargs)
    
    return decorated_function


def get_canvas_client(user: User) -> CanvasAPIClient:
    """Get Canvas client for authenticated user"""
    access_token = token_manager.decrypt_token(user.access_token)
    return CanvasAPIClient(
        base_url=os.getenv('CANVAS_BASE_URL'),
        access_token=access_token
    )


# Authentication endpoints
@app.route('/auth/login', methods=['GET'])
def get_auth_url():
    """Get Canvas OAuth2 authorization URL"""
    state = request.args.get('state')
    auth_url = auth_service.get_authorization_url(state)
    return jsonify({'auth_url': auth_url})


@app.route('/auth/callback', methods=['POST'])
def handle_auth_callback():
    """Handle OAuth2 callback"""
    data = request.get_json()
    code = data.get('code')
    state = data.get('state')
    
    if not code:
        return jsonify({'error': 'Missing authorization code'}), 400
    
    user = auth_service.authenticate_user(code, state)
    if not user:
        return jsonify({'error': 'Authentication failed'}), 401
    
    # Return user info and token
    return jsonify({
        'user': {
            'id': user.id,
            'name': user.name,
            'email': user.email,
            'role': user.role.value
        },
        'access_token': token_manager.decrypt_token(user.access_token)
    })


# User endpoints
@app.route('/api/user/profile', methods=['GET'])
@require_auth
def get_user_profile():
    """Get current user profile"""
    try:
        # Create Canvas client with the token from g.canvas_token
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        # Get user profile from Canvas API
        user_data = client.get_user_info()
        
        return jsonify({
            'id': user_data['id'],
            'name': user_data['name'],
            'email': user_data.get('email', ''),
            'role': 'student',  # Default role, could be determined from Canvas data
            'last_login': user_data.get('last_login', ''),
            'avatar_url': user_data.get('avatar_url', ''),
            'locale': user_data.get('locale', 'en')
        })
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/user/courses', methods=['GET'])
@require_auth
def get_user_courses():
    """Get courses for current user"""
    try:
        logger.info("Starting get_user_courses")
        
        # Create Canvas client with the token from g.canvas_token
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        logger.info("Canvas client created successfully")
        
        enrollment_type = request.args.get('enrollment_type')
        courses_data = client.get_courses(enrollment_type=enrollment_type)
        
        logger.info(f"Retrieved {len(courses_data)} courses from Canvas")
        
        # Group courses by term
        courses_by_term = {}
        for course_data in courses_data:
            # Include all courses, even those without names or with access restrictions
            course_name = course_data.get('name', f"Course {course_data.get('id', 'Unknown')}")
            if not course_data.get('name'):
                logger.info(f"Including course {course_data.get('id')} with generated name: {course_name}")
            
            term_name = course_data.get('term', {}).get('name', 'Unknown Term')
            if term_name not in courses_by_term:
                courses_by_term[term_name] = []
                
            course_info = {
                'id': f"course_{course_data['id']}",
                'canvas_course_id': str(course_data['id']),
                'name': course_name,
                'course_code': course_data.get('course_code', ''),
                'description': course_data.get('description', ''),
                'workflow_state': course_data.get('workflow_state', 'available'),
                'access_restricted_by_date': course_data.get('access_restricted_by_date', False),
                'term': term_name,
                'start_at': course_data.get('start_at'),
                'end_at': course_data.get('end_at')
            }
            courses_by_term[term_name].append(course_info)
        
        # Sort terms by date (Fall 2024, Spring 2025, Fall 2025)
        sorted_terms = sorted(courses_by_term.keys(), key=lambda x: (
            'Fall' in x and '2024' in x and 1,
            'Spring' in x and '2025' in x and 2,
            'Fall' in x and '2025' in x and 3
        ))
        
        # Flatten courses maintaining term order
        simplified_courses = []
        for term in sorted_terms:
            simplified_courses.extend(courses_by_term[term])
        
        logger.info(f"Successfully processed {len(simplified_courses)} courses across {len(courses_by_term)} terms")
        return jsonify({
            'courses': simplified_courses,
            'courses_by_term': courses_by_term,
            'total_courses': len(simplified_courses),
            'terms': sorted_terms
        })
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/courses/consistency', methods=['GET'])
@require_auth
def check_course_consistency():
    """Check consistency between Canvas API courses and app-visible courses"""
    try:
        logger.info("Starting course consistency check")
        
        # Create Canvas client
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        # Get all courses from API
        api_courses = client.get_courses()
        logger.info(f"Retrieved {len(api_courses)} courses from Canvas API")
        
        # Get app-visible courses (simplified for now - in real app, this would come from app state)
        app_courses = []
        for course_data in api_courses:
            # Simulate app filtering (e.g., only starred courses)
            if not course_data.get('access_restricted_by_date', False):
                app_courses.append({
                    'id': course_data.get('id'),
                    'name': course_data.get('name'),
                    'term': course_data.get('term', {})
                })
        
        # Analyze consistency
        report = course_consistency_checker.analyze_course_consistency(api_courses, app_courses)
        
        # Format report
        report_table = course_consistency_checker.format_report_table(report)
        
        return jsonify({
            'report': {
                'total_api_courses': report.total_api_courses,
                'total_app_courses': report.total_app_courses,
                'missing_from_app': report.missing_from_app,
                'restricted_courses': report.restricted_courses,
                'future_courses': report.future_courses,
                'past_courses': report.past_courses,
                'recommendations': report.recommendations
            },
            'formatted_report': report_table
        })
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500


# Course endpoints
@app.route('/api/courses/<course_id>/assignments', methods=['GET'])
@require_auth
def get_course_assignments(course_id: str):
    """Get assignments for a course"""
    try:
        # Create Canvas client with the token from g.canvas_token
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        assignments_data = client.get_assignments(course_id)
        
        assignments = []
        for assignment_data in assignments_data:
            # Convert workflow_state to AssignmentStatus enum
            workflow_state = assignment_data.get('workflow_state', 'published')
            if workflow_state == 'published':
                status = AssignmentStatus.PUBLISHED
            elif workflow_state == 'unpublished':
                status = AssignmentStatus.UNPUBLISHED
            else:
                status = AssignmentStatus.DRAFT
            
            assignment = Assignment(
                id=f"assign_{assignment_data['id']}",
                canvas_assignment_id=str(assignment_data['id']),
                course_id=course_id,
                name=assignment_data['name'],
                description=assignment_data.get('description'),
                points_possible=assignment_data.get('points_possible'),
                grading_type=assignment_data.get('grading_type', 'points'),
                submission_types=assignment_data.get('submission_types', []),
                status=status
            )
            
            # Parse dates
            if assignment_data.get('due_at'):
                assignment.due_at = datetime.fromisoformat(assignment_data['due_at'].replace('Z', '+00:00'))
            if assignment_data.get('lock_at'):
                assignment.lock_at = datetime.fromisoformat(assignment_data['lock_at'].replace('Z', '+00:00'))
            if assignment_data.get('unlock_at'):
                assignment.unlock_at = datetime.fromisoformat(assignment_data['unlock_at'].replace('Z', '+00:00'))
            
            assignments.append(assignment.to_dict())
        
        return jsonify({'assignments': assignments})
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/courses/<course_id>/assignments/<assignment_id>', methods=['GET'])
@require_auth
def get_assignment_details(course_id: str, assignment_id: str):
    """Get detailed assignment information"""
    try:
        # Create Canvas client with the token from g.canvas_token
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        assignment_data = client.get_assignment(course_id, assignment_id)
        
        # Convert workflow_state to AssignmentStatus enum
        workflow_state = assignment_data.get('workflow_state', 'published')
        if workflow_state == 'published':
            status = AssignmentStatus.PUBLISHED
        elif workflow_state == 'unpublished':
            status = AssignmentStatus.UNPUBLISHED
        else:
            status = AssignmentStatus.DRAFT
        
        assignment = Assignment(
            id=f"assign_{assignment_data['id']}",
            canvas_assignment_id=str(assignment_data['id']),
            course_id=course_id,
            name=assignment_data['name'],
            description=assignment_data.get('description'),
            points_possible=assignment_data.get('points_possible'),
            grading_type=assignment_data.get('grading_type', 'points'),
            submission_types=assignment_data.get('submission_types', []),
            allowed_extensions=assignment_data.get('allowed_extensions', []),
            status=status
        )
        
        # Parse dates
        if assignment_data.get('due_at'):
            assignment.due_at = datetime.fromisoformat(assignment_data['due_at'].replace('Z', '+00:00'))
        if assignment_data.get('lock_at'):
            assignment.lock_at = datetime.fromisoformat(assignment_data['lock_at'].replace('Z', '+00:00'))
        if assignment_data.get('unlock_at'):
            assignment.unlock_at = datetime.fromisoformat(assignment_data['unlock_at'].replace('Z', '+00:00'))
        
        return jsonify({'assignment': assignment.to_dict()})
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500


# Submission endpoints
@app.route('/api/courses/<course_id>/assignments/<assignment_id>/submissions', methods=['GET'])
@require_auth
def get_assignment_submissions(course_id: str, assignment_id: str):
    """Get submissions for an assignment"""
    try:
        # Create Canvas client with the token from g.canvas_token
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        submissions_data = client.get_submissions(course_id, assignment_id)
        
        submissions = []
        for submission_data in submissions_data:
            submission = Submission(
                id=f"sub_{submission_data['id']}",
                canvas_submission_id=str(submission_data['id']),
                assignment_id=assignment_id,
                user_id=str(submission_data['user_id']),
                score=submission_data.get('score'),
                grade=submission_data.get('grade'),
                workflow_state=submission_data.get('workflow_state', 'unsubmitted'),
                late=submission_data.get('late', False),
                excused=submission_data.get('excused', False),
                attempt=submission_data.get('attempt', 0),
                body=submission_data.get('body'),
                url=submission_data.get('url'),
                attachments=submission_data.get('attachments', [])
            )
            
            if submission_data.get('submitted_at'):
                submission.submitted_at = datetime.fromisoformat(submission_data['submitted_at'].replace('Z', '+00:00'))
            
            submissions.append(submission.to_dict())
        
        return jsonify({'submissions': submissions})
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500


# File upload endpoints
# File upload functionality moved to AI Assignment help endpoint
# General file upload endpoints removed - use /api/ai/assignment-help for file uploads with AI context
# File uploads are now integrated into the AI assignment help workflow for better context management

# Assignment submission endpoints
@app.route('/api/assignments/submit-text', methods=['POST'])
@require_auth
def submit_assignment_text():
    """Submit an assignment with text entry"""
    try:
        data = request.get_json()
        course_id = data.get('course_id')
        assignment_id = data.get('assignment_id')
        text_content = data.get('text_content')
        comment = data.get('comment', '')
        
        if not all([course_id, assignment_id, text_content]):
            return jsonify({'error': 'Missing required parameters'}), 400
        
        submission_service = CanvasAssignmentSubmissionService(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        submission_info = submission_service.submit_text_entry(
            course_id=course_id,
            assignment_id=assignment_id,
            text_content=text_content,
            comment=comment
        )
        
        return jsonify({
            'success': True,
            'submission': submission_info
        })
        
    except Exception as e:
        logger.error(f"Text submission error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/assignments/submit-files', methods=['POST'])
@require_auth
def submit_assignment_files():
    """Submit an assignment with file uploads"""
    try:
        data = request.get_json()
        course_id = data.get('course_id')
        assignment_id = data.get('assignment_id')
        file_ids = data.get('file_ids', [])
        comment = data.get('comment', '')
        
        if not all([course_id, assignment_id, file_ids]):
            return jsonify({'error': 'Missing required parameters'}), 400
        
        submission_service = CanvasAssignmentSubmissionService(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        submission_info = submission_service.submit_file_upload(
            course_id=course_id,
            assignment_id=assignment_id,
            file_ids=file_ids,
            comment=comment
        )
        
        return jsonify({
            'success': True,
            'submission': submission_info
        })
        
    except Exception as e:
        logger.error(f"File submission error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/assignments/submit-url', methods=['POST'])
@require_auth
def submit_assignment_url():
    """Submit an assignment with a URL"""
    try:
        data = request.get_json()
        course_id = data.get('course_id')
        assignment_id = data.get('assignment_id')
        url_submission = data.get('url')
        comment = data.get('comment', '')
        
        if not all([course_id, assignment_id, url_submission]):
            return jsonify({'error': 'Missing required parameters'}), 400
        
        submission_service = CanvasAssignmentSubmissionService(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        submission_info = submission_service.submit_url(
            course_id=course_id,
            assignment_id=assignment_id,
            url_submission=url_submission,
            comment=comment
        )
        
        return jsonify({
            'success': True,
            'submission': submission_info
        })
        
    except Exception as e:
        logger.error(f"URL submission error: {e}")
        return jsonify({'error': str(e)}), 500


# Calendar integration endpoints
@app.route('/api/calendar/events', methods=['POST'])
@require_auth
def create_calendar_events():
    """Create calendar events from study plan"""
    try:
        data = request.get_json()
        events = data.get('events', [])
        
        # For now, return the events for client-side calendar integration
        # In the future, this could integrate with Google Calendar, Apple Calendar, etc.
        
        return jsonify({
            'success': True,
            'events': events,
            'message': 'Calendar events ready for integration'
        })
        
    except Exception as e:
        logger.error(f"Calendar events error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/calendar/export', methods=['POST'])
@require_auth
def export_calendar_events():
    """Export calendar events in various formats"""
    try:
        data = request.get_json()
        events = data.get('events', [])
        assignments = data.get('assignments', [])
        format_type = data.get('format', 'ics')  # ics, csv, json
        user_email = data.get('user_email')
        
        if format_type == 'ics':
            # Use CalendarService for proper .ics generation
            calendar_service = CalendarService()
            
            if assignments:
                # Generate from assignments
                filepath = calendar_service.create_calendar_events_from_assignments(
                    assignments, user_email
                )
            else:
                # Generate from study plan events
                study_plan = {'tasks': events}
                filepath = calendar_service.create_ics_from_study_plan(study_plan, user_email)
            
            # Read the file content
            with open(filepath, 'r') as f:
                ics_content = f.read()
            
            return jsonify({
                'success': True,
                'format': 'ics',
                'content': ics_content,
                'filename': os.path.basename(filepath)
            })
        elif format_type == 'csv':
            # Generate CSV format
            csv_content = generate_csv_content(events)
            return jsonify({
                'success': True,
                'format': 'csv',
                'content': csv_content,
                'filename': 'study_plan.csv'
            })
        else:
            return jsonify({
                'success': True,
                'format': 'json',
                'content': events,
                'filename': 'study_plan.json'
            })
        
    except Exception as e:
        logger.error(f"Calendar export error: {e}")
        return jsonify({'error': str(e)}), 500


def generate_ics_content(events):
    """Generate ICS calendar format content"""
    ics_lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//Canvas Automation Flow//Study Plan//EN",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH"
    ]
    
    for event in events:
        start_time = event['start_time'].replace(':', '').replace('-', '')
        end_time = event['end_time'].replace(':', '').replace('-', '')
        
        ics_lines.extend([
            "BEGIN:VEVENT",
            f"DTSTART:{start_time}",
            f"DTEND:{end_time}",
            f"SUMMARY:{event['title']}",
            f"DESCRIPTION:{event['description']}",
            "STATUS:CONFIRMED",
            "END:VEVENT"
        ])
    
    ics_lines.append("END:VCALENDAR")
    return '\n'.join(ics_lines)


def generate_csv_content(events):
    """Generate CSV format content"""
    csv_lines = ["Subject,Start Date,Start Time,End Date,End Time,Description"]
    
    for event in events:
        start_dt = datetime.fromisoformat(event['start_time'])
        end_dt = datetime.fromisoformat(event['end_time'])
        
        csv_lines.append(
            f'"{event["title"]}",'
            f'{start_dt.strftime("%Y-%m-%d")},'
            f'{start_dt.strftime("%H:%M")},'
            f'{end_dt.strftime("%Y-%m-%d")},'
            f'{end_dt.strftime("%H:%M")},'
            f'"{event["description"]}"'
        )
    
    return '\n'.join(csv_lines)


# Reminder endpoints
@app.route('/api/reminders', methods=['POST'])
@require_auth
def create_reminder():
    """Create a new reminder"""
    # user = g.current_user  # Fixed: use g.canvas_token instead
    data = request.get_json()
    
    assignment_id = data.get('assignment_id')
    hours_before_due = data.get('hours_before_due', 24)
    
    if not assignment_id:
        return jsonify({'error': 'Missing assignment_id'}), 400
    
    try:
        # Get assignment details
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        assignment_data = client.get_assignment(data.get('course_id'), assignment_id)
        
        assignment = Assignment(
            id=f"assign_{assignment_data['id']}",
            canvas_assignment_id=str(assignment_data['id']),
            course_id=data.get('course_id'),
            name=assignment_data['name'],
            due_at=datetime.fromisoformat(assignment_data['due_at'].replace('Z', '+00:00')) if assignment_data.get('due_at') else None
        )
        
        if not assignment.due_at:
            return jsonify({'error': 'Assignment has no due date'}), 400
        
        # Calculate reminder time
        reminder_time = assignment.due_at - timedelta(hours=hours_before_due)
        
        # Generate reminder message
        if llm_service:
            # Create a temporary user object for LLM service
            temp_user = User(
                id="temp_user",
                name="User",
                email="",
                role=UserRole.STUDENT,
                access_token="",
                last_login=None
            )
            message = llm_service.create_reminder_message(assignment, temp_user, hours_before_due)
        else:
            message = f"Reminder: {assignment.name} is due in {hours_before_due} hours. Don't forget to submit!"
        
        reminder = Reminder(
            id=f"reminder_temp_user_{assignment_id}_{datetime.utcnow().timestamp()}",
            user_id="temp_user",
            assignment_id=assignment_id,
            message=message,
            scheduled_for=reminder_time
        )
        
        # TODO: Save to database
        # db.save_reminder(reminder)
        
        return jsonify({'reminder': reminder.to_dict()})
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/reminders/upcoming', methods=['GET'])
@require_auth
def get_upcoming_reminders():
    """Get upcoming reminders for current user"""
    # user = g.current_user  # Fixed: use g.canvas_token instead
    
    # TODO: Get from database
    # reminders = db.get_upcoming_reminders(user.id)
    
    return jsonify({'reminders': []})


# Feedback endpoints
@app.route('/api/feedback-draft/<submission_id>', methods=['GET'])
@require_auth
def get_feedback_draft(submission_id: str):
    """Get AI-generated feedback draft for a submission"""
    # user = g.current_user  # Fixed: use g.canvas_token instead
    
    # TODO: Get submission and assignment from database
    # submission = db.get_submission(submission_id)
    # assignment = db.get_assignment(submission.assignment_id)
    
    # TODO: Get rubric if available
    # rubric = client.get_rubric(assignment.course_id, assignment.canvas_assignment_id)
    
    # TODO: Generate feedback draft
    # feedback_draft = llm_service.create_feedback_draft(submission, assignment, user, rubric)
    
    return jsonify({'feedback_draft': None})


@app.route('/api/feedback-draft/<submission_id>', methods=['POST'])
@require_auth
def generate_feedback_draft(submission_id: str):
    """Generate new AI feedback draft for a submission"""
    # user = g.current_user  # Fixed: use g.canvas_token instead
    
    if "temp_user" not in ['instructor', 'admin']:
        return jsonify({'error': 'Insufficient permissions'}), 403
    
    # TODO: Implement feedback generation
    return jsonify({'message': 'Feedback generation not yet implemented'})



# File endpoints
@app.route('/api/courses/<course_id>/files', methods=['GET'])
@require_auth
def get_course_files(course_id: str):
    """Get files for a course"""
    try:
        # Create Canvas client with the token from g.canvas_token
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        folder_id = request.args.get('folder_id')
        files_data = client.get_files(course_id, folder_id)
        
        files = []
        for file_data in files_data:
            file_obj = File(
                id=f"file_{file_data['id']}",
                canvas_file_id=str(file_data['id']),
                course_id=course_id,
                folder_id=str(file_data.get('folder_id', '')),
                display_name=file_data.get('display_name', ''),
                filename=file_data.get('filename', ''),
                content_type=file_data.get('content-type', ''),
                size=file_data.get('size', 0),
                url=file_data.get('url', ''),
                download_url=file_data.get('url', ''),  # Same as url for Canvas
                thumbnail_url=file_data.get('thumbnail_url'),
                mime_class=file_data.get('mime_class', ''),
                locked=file_data.get('locked', False),
                hidden=file_data.get('hidden', False),
                uuid=file_data.get('uuid', '')
            )
            
            files.append(file_obj.to_dict())
        
        return jsonify({'files': files})
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/courses/<course_id>/files/<file_id>', methods=['GET'])
@require_auth
def get_file_details(course_id: str, file_id: str):
    """Get detailed file information"""
    try:
        # Create Canvas client with the token from g.canvas_token
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        file_data = client.get_file(course_id, file_id)
        
        file_obj = File(
            id=f"file_{file_data['id']}",
            canvas_file_id=str(file_data['id']),
            course_id=course_id,
            folder_id=str(file_data.get('folder_id', '')),
            display_name=file_data.get('display_name', ''),
            filename=file_data.get('filename', ''),
            content_type=file_data.get('content-type', ''),
            size=file_data.get('size', 0),
            url=file_data.get('url', ''),
            download_url=file_data.get('url', ''),
            thumbnail_url=file_data.get('thumbnail_url'),
            mime_class=file_data.get('mime_class', ''),
            locked=file_data.get('locked', False),
            hidden=file_data.get('hidden', False),
            uuid=file_data.get('uuid', '')
        )
        
        return jsonify({'file': file_obj.to_dict()})
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/courses/<course_id>/folders', methods=['GET'])
@require_auth
def get_course_folders(course_id: str):
    """Get folders for a course"""
    try:
        # Create Canvas client with the token from g.canvas_token
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        folders_data = client.get_folders(course_id)
        
        folders = []
        for folder_data in folders_data:
            folders.append({
                'id': f"folder_{folder_data['id']}",
                'canvas_folder_id': str(folder_data['id']),
                'name': folder_data.get('name', ''),
                'full_name': folder_data.get('full_name', ''),
                'parent_folder_id': folder_data.get('parent_folder_id'),
                'files_count': folder_data.get('files_count', 0),
                'folders_count': folder_data.get('folders_count', 0),
                'locked': folder_data.get('locked', False),
                'hidden': folder_data.get('hidden', False)
            })
        
        return jsonify({'folders': folders})
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/files/<file_id>/download', methods=['GET'])
@require_auth
def download_file(file_id: str):
    """Proxy file download through backend (with authentication)"""
    try:
        # Create Canvas client with the token from g.canvas_token
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        # Get file details to get the download URL
        course_id = request.args.get('course_id')
        if not course_id:
            return jsonify({'error': 'Missing course_id parameter'}), 400
            
        file_data = client.get_file(course_id, file_id)
        download_url = file_data.get('url')
        
        if not download_url:
            return jsonify({'error': 'File download URL not available'}), 404
        
        # Return the download URL for client to use directly
        return jsonify({
            'download_url': download_url,
            'filename': file_data.get('display_name', 'file'),
            'content_type': file_data.get('content-type', 'application/octet-stream'),
            'size': file_data.get('size', 0)
        })
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500


# Notification endpoints
@app.route('/api/notifications/send', methods=['POST'])
@require_auth
def send_notification():
    """Send notification to user"""
    # user = g.current_user  # Fixed: use g.canvas_token instead
    data = request.get_json()
    
    notification_type = data.get('type', 'push')
    message = data.get('message')
    target_user_id = data.get('user_id', 'temp_user')
    
    if not message:
        return jsonify({'error': 'Missing message'}), 400
    
    # TODO: Implement notification sending
    # notification_service.send_notification(target_user_id, message, notification_type)
    
    return jsonify({'message': 'Notification sent successfully'})


# Root endpoint
@app.route('/', methods=['GET'])
def root():
    """Root endpoint with API information"""
    return jsonify({
        'name': 'Canvas Automation Flow API',
        'version': '1.0.0',
        'status': 'running',
        'timestamp': datetime.utcnow().isoformat(),
        'endpoints': {
            'health': '/health',
            'auth': {
                'login': '/auth/login',
                'callback': '/auth/callback'
            },
            'api': {
                'user_profile': '/api/user/profile',
                'user_courses': '/api/user/courses',
                'course_assignments': '/api/courses/{course_id}/assignments',
                'assignment_details': '/api/courses/{course_id}/assignments/{assignment_id}',
                'submissions': '/api/courses/{course_id}/assignments/{assignment_id}/submissions',
                'reminders': '/api/reminders',
                'upcoming_reminders': '/api/reminders/upcoming',
                'feedback_draft': '/api/feedback-draft/{submission_id}',
                'course_files': '/api/courses/{course_id}/files',
                'file_details': '/api/courses/{course_id}/files/{file_id}',
                'course_folders': '/api/courses/{course_id}/folders',
                'file_download': '/api/files/{file_id}/download',
                'notifications': '/api/notifications/send'
            }
        },
        'documentation': 'See README.md for detailed API documentation'
    })

# Health check
@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '1.0.0'
    })


# MARK: - AI-Powered Endpoints

@app.route('/api/ai/assignment-help', methods=['POST'])
@require_auth
def get_assignment_help():
    """Get AI help for an assignment with optional file upload for context"""
    try:
        # Handle both form data (for file uploads) and JSON data
        uploaded_files = []
        data = {}

        # Check for file uploads in form data
        if request.content_type and 'multipart/form-data' in request.content_type:
            # Get form data
            if 'data' in request.form:
                import json as json_module
                data = json_module.loads(request.form.get('data'))
            
            # Handle file uploads
            if 'files' in request.files:
                files = request.files.getlist('files')
                for file in files:
                    if file and file.filename:
                        # Save uploaded file temporarily
                        import tempfile

                        with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(file.filename)[1]) as temp_file:
                            file.save(temp_file.name)
                            temp_file_path = temp_file.name

                        try:
                            # Initialize file upload service
                            upload_service = CanvasFileUploadService(
                                base_url=os.getenv('CANVAS_BASE_URL'),
                                access_token=g.canvas_token
                            )

                            # Upload to user's personal files for context
                            file_info = upload_service.upload_file_to_user(
                                file_path=temp_file_path,
                                parent_folder_path="ai_context"
                            )

                            uploaded_files.append({
                                'id': file_info.get('id'),
                                'display_name': file_info.get('display_name', file.filename),
                                'filename': file_info.get('filename', file.filename),
                                'size': file_info.get('size', 0),
                                'content_type': file_info.get('content-type', 'application/octet-stream'),
                                'url': file_info.get('url'),
                                'description': f'Context file for AI assignment help: {file.filename}'
                            })

                        finally:
                            # Clean up temporary file
                            import os as os_module
                            os_module.unlink(temp_file_path)
        else:
            # Get JSON data for assignment details
            data = request.get_json() or {}
        
        assignment_id = data.get('assignment_id')
        course_id = data.get('course_id')
        question = data.get('question', '')
        help_type = data.get('help_type', 'guidance')  # analysis, guidance, research, solution

        if not assignment_id:
            logger.error(f"Missing assignment_id in request data: {data}")
            return jsonify({'error': 'Assignment ID is required'}), 400

        if not course_id:
            logger.error(f"Missing course_id in request data: {data}")
            return jsonify({'error': 'Course ID is required'}), 400

        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )

        # Get assignment details
        try:
            assignment_data = client.get_assignment(course_id, assignment_id)
            if not assignment_data:
                return jsonify({'error': 'Assignment not found'}), 404
        except CanvasAPIError as e:
            logger.error(f"Canvas API error for assignment {assignment_id}: {e}")
            if "Resource not found" in str(e):
                return jsonify({'error': 'Assignment not found'}), 404
            else:
                return jsonify({'error': f'Cannot access assignment: {str(e)}'}), 403

        # Get course details for context
        try:
            course_data = client.get_course(course_id)
        except:
            course_data = {}

        # Create assignment object
        assignment = Assignment(
            id=f"assignment_{assignment_data['id']}",
            canvas_assignment_id=str(assignment_data['id']),
            course_id=str(assignment_data.get('course_id', course_id)),
            name=assignment_data.get('name', ''),
            description=assignment_data.get('description', ''),
            due_at=datetime.fromisoformat(assignment_data['due_at'].replace('Z', '+00:00')) if assignment_data.get('due_at') else None,
            points_possible=assignment_data.get('points_possible', 0),
            grading_type=assignment_data.get('grading_type', 'points'),
            submission_types=assignment_data.get('submission_types', []),
            allowed_extensions=assignment_data.get('allowed_extensions', []),
            status=AssignmentStatus.PUBLISHED
        )

        # Build context for prompt templates
        from src.llm.prompt_templates import PromptContext, PromptTemplates
        
        prompt_context = PromptContext(
            course_name=course_data.get('name'),
            course_subject=course_data.get('course_code'),
            assignment_type=', '.join(assignment.submission_types),
            due_date=assignment.due_at.isoformat() if assignment.due_at else None,
            points_possible=assignment.points_possible
        )

        # Customize prompt based on help type
        help_type_descriptions = {
            'analysis': "Provide a detailed analysis of the assignment requirements, breaking down what's being asked and what approach should be taken.",
            'guidance': "Provide step-by-step guidance on how to approach this assignment, including strategies and tips.",
            'research': "Conduct research and provide relevant information, examples, and sources to help with this assignment.",
            'solution': "Help develop a complete solution or response for this assignment with detailed explanations."
        }
        
        help_context = help_type_descriptions.get(help_type, help_type_descriptions['guidance'])
        enhanced_question = f"{help_context}\n\nStudent Question: {question}"
        
        # Get context-aware prompt
        prompt = PromptTemplates.get_assignment_help_prompt(
            assignment.name,
            assignment.description or "",
            enhanced_question,
            prompt_context
        )

        # Use appropriate AI service based on help type
        if help_type in ['research', 'solution'] and llm_service.perplexity_adapter:
            # Use Perplexity for research-based help with citations
            response = llm_service.perplexity_adapter.search_facts(prompt, max_results=10)
        elif llm_service.perplexity_adapter and help_type == 'analysis':
            # Use Perplexity for analysis to include factual information
            response = llm_service.perplexity_adapter.search_facts(prompt, max_results=5)
        else:
            # Use Groq for guidance and general help
            messages = [
                {"role": "system", "content": PromptTemplates.ACADEMIC_TUTOR},
                {"role": "user", "content": prompt}
            ]
            response = llm_service.adapter._make_request(messages, temperature=0.5, max_tokens=1500)

        return jsonify({
            'assignment': assignment.to_dict(),
            'help': response.content,
            'model': response.model,
            'sources': getattr(response, 'sources', None),
            'uploaded_files': uploaded_files
        })

    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error in assignment-help: {e}", exc_info=True)
        return jsonify({'error': f'Internal server error: {str(e)}'}), 500

@app.route('/api/ai/study-plan', methods=['POST'])
@require_auth
def generate_study_plan():
    """Generate AI study plan for assignments"""
    try:
        data = request.get_json()
        course_ids = data.get('course_ids', [])
        days_ahead = data.get('days_ahead', 7)
        
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        all_assignments = []
        for course_id in course_ids:
            try:
                assignments_data = client.get_assignments(course_id)
                for assignment_data in assignments_data:
                    assignment = Assignment(
                        id=f"assignment_{assignment_data['id']}",
                        canvas_assignment_id=str(assignment_data['id']),
                        course_id=course_id,
                        name=assignment_data.get('name', ''),
                        description=assignment_data.get('description', ''),
                        due_at=assignment_data.get('due_at'),  # Keep as string for LLM service
                        points_possible=assignment_data.get('points_possible', 0),
                        grading_type=assignment_data.get('grading_type', 'points'),
                        submission_types=assignment_data.get('submission_types', []),
                        allowed_extensions=assignment_data.get('allowed_extensions', []),
                        status=AssignmentStatus.PUBLISHED
                    )
                    all_assignments.append(assignment)
            except CanvasAPIError as e:
                logger.warning(f"Skipping course {course_id} due to access restrictions: {e}")
                continue
        
        # Generate enhanced study plan with grades, syllabus, and calendar
        enhanced_service = EnhancedStudyPlanService(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        enhanced_plan = enhanced_service.generate_enhanced_study_plan(course_ids, days_ahead)
        
        if 'error' in enhanced_plan:
            # Fallback to basic study plan
            study_plan = llm_service.create_study_plan(all_assignments, days_ahead)
            return jsonify({
                'study_plan': study_plan.content,
                'model': study_plan.model,
                'assignments_count': len(all_assignments),
                'days_ahead': days_ahead,
                'enhanced': False
            })
        
        return jsonify({
            'study_plan': enhanced_plan['study_plan'],
            'performance_analysis': enhanced_plan['performance_analysis'],
            'calendar_events': enhanced_plan['calendar_events'],
            'syllabus_insights': enhanced_plan['syllabus_insights'],
            'assignments_count': len(all_assignments),
            'days_ahead': days_ahead,
            'enhanced': True
        })
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/ai/explain-concept', methods=['POST'])
@require_auth
def explain_concept():
    """Get AI explanation of academic concepts"""
    try:
        data = request.get_json()
        concept = data.get('concept', '')
        context = data.get('context', '')
        level = data.get('level', 'undergraduate')  # undergraduate, graduate, beginner
        course_id = data.get('course_id')  # Optional course context
        
        if not concept:
            return jsonify({'error': 'Concept is required'}), 400
        
        # Build course context if provided
        from src.llm.prompt_templates import PromptContext, PromptTemplates
        
        course_context = PromptContext(student_level=level)
        
        if course_id:
            try:
                client = CanvasAPIClient(
                    base_url=os.getenv('CANVAS_BASE_URL'),
                    access_token=g.canvas_token
                )
                course_data = client.get_course(course_id)
                course_context.course_name = course_data.get('name')
                course_context.course_subject = course_data.get('course_code')
            except:
                pass
        
        # Get context-aware prompt
        prompt = PromptTemplates.get_concept_explanation_prompt(
            concept, context, level, course_context
        )
        
        # Use Perplexity for fact-based explanations when available
        if llm_service.perplexity_adapter:
            response = llm_service.perplexity_adapter.search_facts(prompt, max_results=10)
        else:
            messages = [
                {"role": "system", "content": PromptTemplates.ACADEMIC_TUTOR},
                {"role": "user", "content": prompt}
            ]
            response = llm_service.adapter._make_request(messages, temperature=0.3, max_tokens=1200)
        
        return jsonify({
            'concept': concept,
            'explanation': response.content,
            'model': response.model,
            'sources': getattr(response, 'sources', None),
            'level': level
        })
        
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/ai/feedback-draft', methods=['POST'])
@require_auth
def ai_generate_feedback_draft():
    """Generate AI feedback draft for submissions"""
    try:
        data = request.get_json()
        assignment_id = data.get('assignment_id')
        submission_content = data.get('submission_content', '')
        feedback_type = data.get('feedback_type', 'constructive')  # constructive, detailed, encouraging
        
        if not assignment_id:
            return jsonify({'error': 'Assignment ID is required'}), 400
        
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        # Get assignment details
        assignment_data = client.get_assignment_details(assignment_id)
        if not assignment_data:
            return jsonify({'error': 'Assignment not found'}), 404
        
        assignment = Assignment(
            id=f"assignment_{assignment_data['id']}",
            canvas_assignment_id=str(assignment_data['id']),
            course_id=str(assignment_data.get('course_id', '')),
            name=assignment_data.get('name', ''),
            description=assignment_data.get('description', ''),
            due_at=assignment_data.get('due_at'),
            points_possible=assignment_data.get('points_possible', 0),
            grading_type=assignment_data.get('grading_type', 'points'),
            submission_types=assignment_data.get('submission_types', []),
            allowed_extensions=assignment_data.get('allowed_extensions', []),
            status=AssignmentStatus.PUBLISHED
        )
        
        # Create mock submission
        submission = Submission(
            id=f"submission_temp",
            canvas_submission_id="temp",
            assignment_id=assignment_id,
            user_id="temp",
            body=submission_content
        )
        
        # Generate feedback
        feedback = llm_service.generate_feedback_draft(assignment, submission, feedback_type)
        
        return jsonify({
            'assignment': assignment.to_dict(),
            'feedback': feedback.content,
            'model': feedback.model,
            'feedback_type': feedback_type
        })
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500


# Quiz/Exam Endpoints
@app.route('/api/courses/<course_id>/quizzes', methods=['GET'])
@require_auth
def get_course_quizzes(course_id: str):
    """Get quizzes/exams for a course"""
    try:
        quiz_service = CanvasQuizService(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        quizzes = quiz_service.get_course_quizzes(course_id)
        
        return jsonify({
            'quizzes': [q.to_dict() for q in quizzes],
            'count': len(quizzes)
        })
        
    except Exception as e:
        logger.error(f"Error fetching quizzes: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/courses/<course_id>/quizzes/<quiz_id>', methods=['GET'])
@require_auth
def get_quiz_details(course_id: str, quiz_id: str):
    """Get detailed quiz information"""
    try:
        quiz_service = CanvasQuizService(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        quiz = quiz_service.get_quiz(course_id, quiz_id)
        
        if not quiz:
            return jsonify({'error': 'Quiz not found'}), 404
        
        return jsonify({'quiz': quiz.to_dict()})
        
    except Exception as e:
        logger.error(f"Error fetching quiz details: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/courses/<course_id>/quizzes/<quiz_id>/start', methods=['POST'])
@require_auth
def start_quiz_attempt(course_id: str, quiz_id: str):
    """Start a new quiz attempt"""
    try:
        quiz_service = CanvasQuizService(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        # Check if quiz exists and is available
        quiz = quiz_service.get_quiz(course_id, quiz_id)
        if not quiz:
            return jsonify({'error': 'Quiz not found'}), 404
        
        if not quiz.is_available():
            return jsonify({'error': 'Quiz is not available'}), 403
        
        # Start the attempt
        submission_data = quiz_service.start_quiz_attempt(course_id, quiz_id)
        
        return jsonify({
            'submission': submission_data,
            'quiz': quiz.to_dict()
        })
        
    except Exception as e:
        logger.error(f"Error starting quiz attempt: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/quiz_submissions/<submission_id>/questions', methods=['GET'])
@require_auth
def get_quiz_submission_questions(submission_id: str):
    """Get questions for an active quiz submission"""
    try:
        quiz_service = CanvasQuizService(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        questions = quiz_service.get_quiz_questions(submission_id)
        
        return jsonify({
            'questions': [q.to_dict() for q in questions],
            'count': len(questions)
        })
        
    except Exception as e:
        logger.error(f"Error fetching quiz questions: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/quiz_submissions/<submission_id>/answer', methods=['POST'])
@require_auth
def answer_quiz_question(submission_id: str):
    """Submit an answer to a quiz question"""
    try:
        data = request.get_json()
        question_id = data.get('question_id')
        answer = data.get('answer')
        validation_token = data.get('validation_token')
        
        if not question_id or answer is None or not validation_token:
            return jsonify({'error': 'question_id, answer, and validation_token are required'}), 400
        
        quiz_service = CanvasQuizService(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        success = quiz_service.answer_question(
            submission_id,
            question_id,
            answer,
            validation_token
        )
        
        if success:
            return jsonify({'success': True, 'message': 'Answer submitted'})
        else:
            return jsonify({'error': 'Failed to submit answer'}), 500
        
    except Exception as e:
        logger.error(f"Error answering quiz question: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/courses/<course_id>/quizzes/<quiz_id>/submissions/<submission_id>/complete', methods=['POST'])
@require_auth
def complete_quiz(course_id: str, quiz_id: str, submission_id: str):
    """Complete and submit a quiz"""
    try:
        data = request.get_json()
        validation_token = data.get('validation_token')
        
        if not validation_token:
            return jsonify({'error': 'validation_token is required'}), 400
        
        quiz_service = CanvasQuizService(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        success = quiz_service.complete_quiz_submission(
            course_id,
            quiz_id,
            submission_id,
            validation_token
        )
        
        if success:
            return jsonify({'success': True, 'message': 'Quiz completed'})
        else:
            return jsonify({'error': 'Failed to complete quiz'}), 500
        
    except Exception as e:
        logger.error(f"Error completing quiz: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/courses/<course_id>/quizzes/<quiz_id>/submissions/<submission_id>/time', methods=['GET'])
@require_auth
def get_quiz_time_remaining(course_id: str, quiz_id: str, submission_id: str):
    """Get time remaining for a timed quiz"""
    try:
        quiz_service = CanvasQuizService(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        time_data = quiz_service.get_submission_time_remaining(
            course_id,
            quiz_id,
            submission_id
        )
        
        if time_data:
            return jsonify(time_data)
        else:
            return jsonify({'error': 'Could not fetch time data'}), 500
        
    except Exception as e:
        logger.error(f"Error fetching time remaining: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/ai/quiz-question-help', methods=['POST'])
@require_auth
def ai_quiz_question_help():
    """Get AI help for a quiz question during active attempt"""
    try:
        data = request.get_json()
        question_text = data.get('question_text')
        question_type = data.get('question_type')
        answers = data.get('answers', [])
        course_context = data.get('course_context', '')
        
        if not question_text:
            return jsonify({'error': 'question_text is required'}), 400
        
        # Use Perplexity for research-based help
        if llm_service and llm_service.perplexity_adapter:
            prompt = f"""Help with this quiz question:

Question: {question_text}

Type: {question_type}

{f'Course Context: {course_context}' if course_context else ''}

Provide:
1. Explanation of the concept
2. Key information to consider
3. Approach to solve

Do NOT directly give the answer, but help understand the concept."""

            response = llm_service.perplexity_adapter.search_facts(prompt, max_results=5)
            
            return jsonify({
                'help': response.content,
                'sources': response.sources,
                'model': response.model
            })
        else:
            return jsonify({'error': 'AI service not available'}), 503
        
    except Exception as e:
        logger.error(f"Error providing quiz help: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/ai/complete-assignment', methods=['POST'])
@require_auth
def ai_complete_assignment():
    """Complete an assignment using AI with citations"""
    try:
        data = request.get_json()
        course_id = data.get('course_id')
        assignment_id = data.get('assignment_id')
        additional_context = data.get('additional_context', '')
        use_citations = data.get('use_citations', True)
        generate_document = data.get('generate_document', False)
        document_format = data.get('document_format', 'pdf')  # pdf, docx, latex
        
        if not assignment_id or not course_id:
            return jsonify({'error': 'Assignment ID and Course ID are required'}), 400
        
        # Get assignment details
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        assignment_data = client.get_assignment(course_id, assignment_id)
        
        assignment = Assignment(
            id=f"assignment_{assignment_data['id']}",
            canvas_assignment_id=str(assignment_data['id']),
            course_id=course_id,
            name=assignment_data.get('name', ''),
            description=assignment_data.get('description', ''),
            due_at=assignment_data.get('due_at'),
            points_possible=assignment_data.get('points_possible', 0),
            grading_type=assignment_data.get('grading_type', 'points'),
            submission_types=assignment_data.get('submission_types', []),
            allowed_extensions=assignment_data.get('allowed_extensions', []),
            status=AssignmentStatus.PUBLISHED
        )
        
        # Complete assignment using AI
        completion_service = AssignmentCompletionService(llm_service)
        response = completion_service.complete_assignment(
            assignment,
            context_files=data.get('context_files', []),
            additional_context=additional_context,
            use_citations=use_citations
        )
        
        result = {
            'assignment': assignment.to_dict(),
            'completion': response.content,
            'model': response.model,
            'sources': response.sources,
            'metadata': response.metadata
        }
        
        # Generate document if requested
        if generate_document:
            doc_service = DocumentGenerationService()
            
            if document_format == 'latex':
                latex_doc = doc_service.generate_latex_document(
                    response.content,
                    assignment.name,
                    "Student"
                )
                result['latex_document'] = latex_doc
            elif document_format == 'pdf':
                pdf_path = doc_service.generate_pdf_from_markdown(
                    response.content,
                    assignment.name,
                    "Student"
                )
                if pdf_path:
                    result['document_path'] = pdf_path
            elif document_format == 'docx':
                docx_path = doc_service.generate_docx(
                    response.content,
                    assignment.name,
                    "Student"
                )
                if docx_path:
                    result['document_path'] = docx_path
        
        return jsonify(result)
        
    except Exception as e:
        logger.error(f"Error completing assignment: {e}")
        return jsonify({'error': str(e)}), 500




# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Resource not found'}), 404


@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Internal server error: {error}")
    return jsonify({'error': 'Internal server error'}), 500


if __name__ == '__main__':
    # Development server
    app.run(debug=True, host='0.0.0.0', port=5000)
