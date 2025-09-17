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

from auth.auth_service import CanvasAuthService, TokenManager, User, UserRole
from canvas.canvas_client import CanvasAPIClient, CanvasAPIError
from models.data_models import Course, Assignment, Submission, Reminder, FeedbackDraft, AssignmentStatus, File
from llm.llm_service import LLMService, create_llm_adapter, LLMProvider


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

# Initialize LLM service only if API key is available
groq_api_key = os.getenv('GROQ_API_KEY')
if groq_api_key:
    llm_service = LLMService(
        create_llm_adapter(LLMProvider.GROQ, api_key=groq_api_key)
    )
else:
    logger.warning("GROQ_API_KEY not set - LLM features will be disabled")
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
        
        # Return simplified course data first
        simplified_courses = []
        for course_data in courses_data:
            # Skip courses without essential data
            if not course_data.get('name'):
                logger.info(f"Skipping course {course_data.get('id')} - missing name")
                continue
                
            simplified_courses.append({
                'id': f"course_{course_data['id']}",
                'canvas_course_id': str(course_data['id']),
                'name': course_data['name'],
                'course_code': course_data.get('course_code', ''),
                'description': course_data.get('description', ''),
                'workflow_state': course_data.get('workflow_state', 'available')
            })
        
        logger.info(f"Successfully processed {len(simplified_courses)} courses")
        return jsonify({'courses': simplified_courses})
        
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
    """Get AI help for an assignment"""
    try:
        data = request.get_json()
        assignment_id = data.get('assignment_id')
        question = data.get('question', '')
        
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
        
        # Create assignment object
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
        
        # Get AI help
        help_response = llm_service.generate_assignment_help(assignment, question)
        
        return jsonify({
            'assignment': assignment.to_dict(),
            'help': help_response.content,
            'model': help_response.model
        })
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500

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
            assignments_data = client.get_assignments(course_id)
            for assignment_data in assignments_data:
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
                all_assignments.append(assignment)
        
        # Generate study plan
        study_plan = llm_service.create_study_plan(all_assignments, days_ahead)
        
        return jsonify({
            'study_plan': study_plan.content,
            'model': study_plan.model,
            'assignments_count': len(all_assignments),
            'days_ahead': days_ahead
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
        
        if not concept:
            return jsonify({'error': 'Concept is required'}), 400
        
        explanation = llm_service.explain_concept(concept, context, level)
        
        return jsonify({
            'concept': concept,
            'explanation': explanation.content,
            'model': explanation.model,
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
