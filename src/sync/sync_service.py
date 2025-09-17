"""
Canvas data sync strategy with caching
Handles periodic synchronization of Canvas data with local database
"""

import os
import json
import time
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List, Set
from dataclasses import dataclass
from enum import Enum
import logging
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed

from auth.auth_service import CanvasAuthService, User
from canvas.canvas_client import CanvasAPIClient, CanvasAPIError
from models.data_models import Course, Assignment, Submission, DatabaseInterface


class SyncStatus(Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"


@dataclass
class SyncJob:
    """Sync job data model"""
    id: str
    user_id: str
    sync_type: str  # 'full', 'courses', 'assignments', 'submissions'
    status: SyncStatus = SyncStatus.PENDING
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    error_message: Optional[str] = None
    items_processed: int = 0
    items_total: int = 0
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


class CanvasSyncService:
    """Canvas data synchronization service"""
    
    def __init__(self, auth_service: CanvasAuthService, database: DatabaseInterface):
        self.auth_service = auth_service
        self.database = database
        self.logger = logging.getLogger(__name__)
        self.sync_jobs = {}  # In production, use proper database
        self.running_syncs = set()
        
        # Sync configuration
        self.sync_interval = int(os.getenv('SYNC_INTERVAL_MINUTES', '15')) * 60  # Convert to seconds
        self.batch_size = int(os.getenv('SYNC_BATCH_SIZE', '50'))
        self.max_concurrent_syncs = int(os.getenv('MAX_CONCURRENT_SYNCS', '5'))
        
        # Cache configuration
        self.cache_ttl = int(os.getenv('CACHE_TTL_MINUTES', '30')) * 60
        
        # Start background sync thread
        self.sync_thread = threading.Thread(target=self._background_sync, daemon=True)
        self.sync_thread.start()
    
    def _get_canvas_client(self, user: User) -> CanvasAPIClient:
        """Get Canvas client for user"""
        access_token = self.auth_service.token_manager.decrypt_token(user.access_token)
        return CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=access_token
        )
    
    def _create_sync_job(self, user_id: str, sync_type: str, metadata: Dict[str, Any] = None) -> SyncJob:
        """Create a new sync job"""
        job = SyncJob(
            id=f"sync_{user_id}_{sync_type}_{datetime.utcnow().timestamp()}",
            user_id=user_id,
            sync_type=sync_type,
            metadata=metadata or {}
        )
        self.sync_jobs[job.id] = job
        return job
    
    def _update_sync_job(self, job_id: str, **updates):
        """Update sync job status"""
        if job_id in self.sync_jobs:
            job = self.sync_jobs[job_id]
            for key, value in updates.items():
                if hasattr(job, key):
                    setattr(job, key, value)
    
    def sync_user_courses(self, user_id: str, force_refresh: bool = False) -> str:
        """Sync courses for a user"""
        user = self.auth_service.get_user(user_id)
        if not user:
            raise ValueError(f"User {user_id} not found")
        
        if not force_refresh and user_id in self.running_syncs:
            self.logger.warning(f"Sync already running for user {user_id}")
            return None
        
        job = self._create_sync_job(user_id, 'courses')
        self.running_syncs.add(user_id)
        
        try:
            self._update_sync_job(job.id, status=SyncStatus.RUNNING, started_at=datetime.utcnow())
            
            client = self._get_canvas_client(user)
            courses_data = client.get_courses()
            
            self._update_sync_job(job.id, items_total=len(courses_data))
            
            courses_synced = 0
            for course_data in courses_data:
                try:
                    course = Course(
                        id=f"course_{course_data['id']}",
                        canvas_course_id=str(course_data['id']),
                        name=course_data['name'],
                        course_code=course_data.get('course_code', ''),
                        description=course_data.get('description'),
                        workflow_state=course_data.get('workflow_state', 'available')
                    )
                    
                    # Parse dates
                    if course_data.get('start_at'):
                        course.start_at = datetime.fromisoformat(course_data['start_at'].replace('Z', '+00:00'))
                    if course_data.get('end_at'):
                        course.end_at = datetime.fromisoformat(course_data['end_at'].replace('Z', '+00:00'))
                    
                    self.database.save_course(course)
                    courses_synced += 1
                    
                    self._update_sync_job(job.id, items_processed=courses_synced)
                    
                except Exception as e:
                    self.logger.error(f"Failed to sync course {course_data.get('id')}: {e}")
            
            self._update_sync_job(job.id, 
                                status=SyncStatus.COMPLETED,
                                completed_at=datetime.utcnow(),
                                items_processed=courses_synced)
            
            self.logger.info(f"Synced {courses_synced} courses for user {user_id}")
            return job.id
            
        except Exception as e:
            self._update_sync_job(job.id,
                                status=SyncStatus.FAILED,
                                error_message=str(e),
                                completed_at=datetime.utcnow())
            self.logger.error(f"Course sync failed for user {user_id}: {e}")
            raise
        finally:
            self.running_syncs.discard(user_id)
    
    def sync_course_assignments(self, user_id: str, course_id: str, force_refresh: bool = False) -> str:
        """Sync assignments for a course"""
        user = self.auth_service.get_user(user_id)
        if not user:
            raise ValueError(f"User {user_id} not found")
        
        job = self._create_sync_job(user_id, 'assignments', {'course_id': course_id})
        
        try:
            self._update_sync_job(job.id, status=SyncStatus.RUNNING, started_at=datetime.utcnow())
            
            client = self._get_canvas_client(user)
            assignments_data = client.get_assignments(course_id)
            
            self._update_sync_job(job.id, items_total=len(assignments_data))
            
            assignments_synced = 0
            for assignment_data in assignments_data:
                try:
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
                        status=assignment_data.get('workflow_state', 'published')
                    )
                    
                    # Parse dates
                    if assignment_data.get('due_at'):
                        assignment.due_at = datetime.fromisoformat(assignment_data['due_at'].replace('Z', '+00:00'))
                    if assignment_data.get('lock_at'):
                        assignment.lock_at = datetime.fromisoformat(assignment_data['lock_at'].replace('Z', '+00:00'))
                    if assignment_data.get('unlock_at'):
                        assignment.unlock_at = datetime.fromisoformat(assignment_data['unlock_at'].replace('Z', '+00:00'))
                    
                    self.database.save_assignment(assignment)
                    assignments_synced += 1
                    
                    self._update_sync_job(job.id, items_processed=assignments_synced)
                    
                except Exception as e:
                    self.logger.error(f"Failed to sync assignment {assignment_data.get('id')}: {e}")
            
            self._update_sync_job(job.id,
                                status=SyncStatus.COMPLETED,
                                completed_at=datetime.utcnow(),
                                items_processed=assignments_synced)
            
            self.logger.info(f"Synced {assignments_synced} assignments for course {course_id}")
            return job.id
            
        except Exception as e:
            self._update_sync_job(job.id,
                                status=SyncStatus.FAILED,
                                error_message=str(e),
                                completed_at=datetime.utcnow())
            self.logger.error(f"Assignment sync failed for course {course_id}: {e}")
            raise
    
    def sync_assignment_submissions(self, user_id: str, course_id: str, assignment_id: str) -> str:
        """Sync submissions for an assignment"""
        user = self.auth_service.get_user(user_id)
        if not user:
            raise ValueError(f"User {user_id} not found")
        
        job = self._create_sync_job(user_id, 'submissions', 
                                  {'course_id': course_id, 'assignment_id': assignment_id})
        
        try:
            self._update_sync_job(job.id, status=SyncStatus.RUNNING, started_at=datetime.utcnow())
            
            client = self._get_canvas_client(user)
            submissions_data = client.get_submissions(course_id, assignment_id)
            
            self._update_sync_job(job.id, items_total=len(submissions_data))
            
            submissions_synced = 0
            for submission_data in submissions_data:
                try:
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
                    
                    self.database.save_submission(submission)
                    submissions_synced += 1
                    
                    self._update_sync_job(job.id, items_processed=submissions_synced)
                    
                except Exception as e:
                    self.logger.error(f"Failed to sync submission {submission_data.get('id')}: {e}")
            
            self._update_sync_job(job.id,
                                status=SyncStatus.COMPLETED,
                                completed_at=datetime.utcnow(),
                                items_processed=submissions_synced)
            
            self.logger.info(f"Synced {submissions_synced} submissions for assignment {assignment_id}")
            return job.id
            
        except Exception as e:
            self._update_sync_job(job.id,
                                status=SyncStatus.FAILED,
                                error_message=str(e),
                                completed_at=datetime.utcnow())
            self.logger.error(f"Submission sync failed for assignment {assignment_id}: {e}")
            raise
    
    def sync_user_full(self, user_id: str) -> str:
        """Perform full sync for a user (courses, assignments, submissions)"""
        user = self.auth_service.get_user(user_id)
        if not user:
            raise ValueError(f"User {user_id} not found")
        
        job = self._create_sync_job(user_id, 'full')
        
        try:
            self._update_sync_job(job.id, status=SyncStatus.RUNNING, started_at=datetime.utcnow())
            
            # Sync courses first
            courses_job_id = self.sync_user_courses(user_id, force_refresh=True)
            courses_job = self.sync_jobs.get(courses_job_id)
            
            if courses_job and courses_job.status == SyncStatus.COMPLETED:
                # Get synced courses
                courses = self.database.get_courses_for_user(user_id)
                
                # Sync assignments for each course
                for course in courses:
                    try:
                        self.sync_course_assignments(user_id, course.canvas_course_id)
                    except Exception as e:
                        self.logger.error(f"Failed to sync assignments for course {course.id}: {e}")
                
                # TODO: Sync submissions for recent assignments
                # This would be done in batches to avoid overwhelming the API
            
            self._update_sync_job(job.id,
                                status=SyncStatus.COMPLETED,
                                completed_at=datetime.utcnow())
            
            self.logger.info(f"Full sync completed for user {user_id}")
            return job.id
            
        except Exception as e:
            self._update_sync_job(job.id,
                                status=SyncStatus.FAILED,
                                error_message=str(e),
                                completed_at=datetime.utcnow())
            self.logger.error(f"Full sync failed for user {user_id}: {e}")
            raise
    
    def _background_sync(self):
        """Background thread for periodic sync"""
        while True:
            try:
                time.sleep(self.sync_interval)
                
                # Get all active users
                active_users = [user for user in self.auth_service.users_db.values()
                              if self.auth_service.is_token_valid(user)]
                
                # Sync users in parallel (with limit)
                with ThreadPoolExecutor(max_workers=self.max_concurrent_syncs) as executor:
                    futures = []
                    
                    for user in active_users:
                        if user.id not in self.running_syncs:
                            future = executor.submit(self.sync_user_courses, user.id)
                            futures.append(future)
                    
                    # Wait for completion
                    for future in as_completed(futures):
                        try:
                            job_id = future.result()
                            if job_id:
                                self.logger.info(f"Background sync completed: {job_id}")
                        except Exception as e:
                            self.logger.error(f"Background sync failed: {e}")
                
            except Exception as e:
                self.logger.error(f"Background sync thread error: {e}")
    
    def get_sync_status(self, job_id: str) -> Optional[SyncJob]:
        """Get sync job status"""
        return self.sync_jobs.get(job_id)
    
    def get_user_sync_history(self, user_id: str, limit: int = 10) -> List[SyncJob]:
        """Get sync history for a user"""
        user_jobs = [job for job in self.sync_jobs.values() if job.user_id == user_id]
        user_jobs.sort(key=lambda x: x.started_at or datetime.min, reverse=True)
        return user_jobs[:limit]
    
    def trigger_sync(self, user_id: str, sync_type: str = 'courses') -> str:
        """Manually trigger sync for a user"""
        if sync_type == 'full':
            return self.sync_user_full(user_id)
        elif sync_type == 'courses':
            return self.sync_user_courses(user_id, force_refresh=True)
        else:
            raise ValueError(f"Unknown sync type: {sync_type}")


# Example usage
if __name__ == "__main__":
    from ..auth.auth_service import CanvasAuthService, TokenManager
    
    # Initialize services
    token_manager = TokenManager()
    auth_service = CanvasAuthService(
        canvas_base_url=os.getenv('CANVAS_BASE_URL'),
        client_id=os.getenv('CANVAS_CLIENT_ID'),
        client_secret=os.getenv('CANVAS_CLIENT_SECRET'),
        redirect_uri=os.getenv('CANVAS_REDIRECT_URI'),
        token_manager=token_manager
    )
    
    # TODO: Initialize database
    # database = YourDatabaseImplementation()
    # sync_service = CanvasSyncService(auth_service, database)
    
    print("✅ Canvas sync service initialized")
    print(f"Sync interval: {int(os.getenv('SYNC_INTERVAL_MINUTES', '15'))} minutes")
    print(f"Batch size: {int(os.getenv('SYNC_BATCH_SIZE', '50'))}")
    print(f"Max concurrent syncs: {int(os.getenv('MAX_CONCURRENT_SYNCS', '5'))}")
