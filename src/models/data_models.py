"""
Data models for Canvas automation system
Defines core entities: Course, Assignment, Submission, Reminder, FeedbackDraft, File
"""

from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional, List, Dict, Any
from enum import Enum
import json


class AssignmentStatus(Enum):
    DRAFT = "draft"
    PUBLISHED = "published"
    UNPUBLISHED = "unpublished"


class SubmissionStatus(Enum):
    SUBMITTED = "submitted"
    LATE = "late"
    MISSING = "missing"
    GRADED = "graded"


class ReminderStatus(Enum):
    PENDING = "pending"
    SENT = "sent"
    FAILED = "failed"
    CANCELLED = "cancelled"


@dataclass
class Course:
    """Course data model"""
    id: str
    canvas_course_id: str
    name: str
    course_code: str
    description: Optional[str] = None
    start_at: Optional[datetime] = None
    end_at: Optional[datetime] = None
    enrollment_term_id: Optional[str] = None
    workflow_state: str = "available"
    created_at: datetime = field(default_factory=datetime.utcnow)
    updated_at: datetime = field(default_factory=datetime.utcnow)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        data = {
            'id': self.id,
            'canvas_course_id': self.canvas_course_id,
            'name': self.name,
            'course_code': self.course_code,
            'description': self.description,
            'workflow_state': self.workflow_state,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }
        
        if self.start_at:
            data['start_at'] = self.start_at.isoformat()
        if self.end_at:
            data['end_at'] = self.end_at.isoformat()
        if self.enrollment_term_id:
            data['enrollment_term_id'] = self.enrollment_term_id
            
        return data


@dataclass
class Assignment:
    """Assignment data model"""
    id: str
    canvas_assignment_id: str
    course_id: str
    name: str
    description: Optional[str] = None
    due_at: Optional[datetime] = None
    lock_at: Optional[datetime] = None
    unlock_at: Optional[datetime] = None
    points_possible: Optional[float] = None
    grading_type: str = "points"
    submission_types: List[str] = field(default_factory=list)
    allowed_extensions: List[str] = field(default_factory=list)
    status: AssignmentStatus = AssignmentStatus.PUBLISHED
    created_at: datetime = field(default_factory=datetime.utcnow)
    updated_at: datetime = field(default_factory=datetime.utcnow)
    
    def is_due_soon(self, hours: int = 24) -> bool:
        """Check if assignment is due within specified hours"""
        if not self.due_at:
            return False
        time_until_due = self.due_at - datetime.utcnow()
        return 0 < time_until_due.total_seconds() <= hours * 3600
    
    def is_overdue(self) -> bool:
        """Check if assignment is overdue"""
        if not self.due_at:
            return False
        return datetime.utcnow() > self.due_at
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        data = {
            'id': self.id,
            'canvas_assignment_id': self.canvas_assignment_id,
            'course_id': self.course_id,
            'name': self.name,
            'description': self.description,
            'points_possible': self.points_possible,
            'grading_type': self.grading_type,
            'submission_types': self.submission_types,
            'allowed_extensions': self.allowed_extensions,
            'status': self.status.value,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }
        
        if self.due_at:
            data['due_at'] = self.due_at.isoformat()
        if self.lock_at:
            data['lock_at'] = self.lock_at.isoformat()
        if self.unlock_at:
            data['unlock_at'] = self.unlock_at.isoformat()
            
        return data


@dataclass
class Submission:
    """Submission data model"""
    id: str
    canvas_submission_id: str
    assignment_id: str
    user_id: str
    submitted_at: Optional[datetime] = None
    score: Optional[float] = None
    grade: Optional[str] = None
    workflow_state: str = "unsubmitted"
    late: bool = False
    excused: bool = False
    attempt: int = 0
    body: Optional[str] = None  # Text submission content
    url: Optional[str] = None  # URL submission
    attachments: List[Dict[str, Any]] = field(default_factory=list)
    comments: List[Dict[str, Any]] = field(default_factory=list)
    created_at: datetime = field(default_factory=datetime.utcnow)
    updated_at: datetime = field(default_factory=datetime.utcnow)
    
    @property
    def status(self) -> SubmissionStatus:
        """Determine submission status"""
        if self.workflow_state == "submitted":
            if self.late:
                return SubmissionStatus.LATE
            elif self.score is not None:
                return SubmissionStatus.GRADED
            else:
                return SubmissionStatus.SUBMITTED
        else:
            return SubmissionStatus.MISSING
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        data = {
            'id': self.id,
            'canvas_submission_id': self.canvas_submission_id,
            'assignment_id': self.assignment_id,
            'user_id': self.user_id,
            'score': self.score,
            'grade': self.grade,
            'workflow_state': self.workflow_state,
            'late': self.late,
            'excused': self.excused,
            'attempt': self.attempt,
            'body': self.body,
            'url': self.url,
            'attachments': self.attachments,
            'comments': self.comments,
            'status': self.status.value,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }
        
        if self.submitted_at:
            data['submitted_at'] = self.submitted_at.isoformat()
            
        return data


@dataclass
class File:
    """File data model"""
    id: str
    canvas_file_id: str
    course_id: str
    folder_id: Optional[str] = None
    display_name: str = ""
    filename: str = ""
    content_type: str = ""
    size: int = 0
    url: str = ""
    download_url: str = ""
    thumbnail_url: Optional[str] = None
    mime_class: str = ""
    locked: bool = False
    hidden: bool = False
    uuid: str = ""
    created_at: datetime = field(default_factory=datetime.utcnow)
    updated_at: datetime = field(default_factory=datetime.utcnow)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        return {
            'id': self.id,
            'canvas_file_id': self.canvas_file_id,
            'course_id': self.course_id,
            'folder_id': self.folder_id,
            'display_name': self.display_name,
            'filename': self.filename,
            'content_type': self.content_type,
            'size': self.size,
            'url': self.url,
            'download_url': self.download_url,
            'thumbnail_url': self.thumbnail_url,
            'mime_class': self.mime_class,
            'locked': self.locked,
            'hidden': self.hidden,
            'uuid': self.uuid,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }


@dataclass
class Reminder:
    """Reminder data model"""
    id: str
    user_id: str
    assignment_id: str
    message: str
    scheduled_for: datetime
    status: ReminderStatus = ReminderStatus.PENDING
    notification_type: str = "push"  # push, email, sms
    sent_at: Optional[datetime] = None
    failure_reason: Optional[str] = None
    created_at: datetime = field(default_factory=datetime.utcnow)
    updated_at: datetime = field(default_factory=datetime.utcnow)
    
    def is_due(self) -> bool:
        """Check if reminder is due to be sent"""
        return datetime.utcnow() >= self.scheduled_for and self.status == ReminderStatus.PENDING
    
    def mark_sent(self) -> None:
        """Mark reminder as sent"""
        self.status = ReminderStatus.SENT
        self.sent_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()
    
    def mark_failed(self, reason: str) -> None:
        """Mark reminder as failed"""
        self.status = ReminderStatus.FAILED
        self.failure_reason = reason
        self.updated_at = datetime.utcnow()
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        data = {
            'id': self.id,
            'user_id': self.user_id,
            'assignment_id': self.assignment_id,
            'message': self.message,
            'scheduled_for': self.scheduled_for.isoformat(),
            'status': self.status.value,
            'notification_type': self.notification_type,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }
        
        if self.sent_at:
            data['sent_at'] = self.sent_at.isoformat()
        if self.failure_reason:
            data['failure_reason'] = self.failure_reason
            
        return data


@dataclass
class FeedbackDraft:
    """AI-generated feedback draft"""
    id: str
    submission_id: str
    instructor_id: str
    content: str
    rubric_scores: Optional[Dict[str, float]] = None
    suggestions: List[str] = field(default_factory=list)
    confidence_score: Optional[float] = None
    model_used: str = "groq-llama"
    is_approved: bool = False
    approved_at: Optional[datetime] = None
    created_at: datetime = field(default_factory=datetime.utcnow)
    updated_at: datetime = field(default_factory=datetime.utcnow)
    
    def approve(self) -> None:
        """Mark feedback as approved"""
        self.is_approved = True
        self.approved_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        data = {
            'id': self.id,
            'submission_id': self.submission_id,
            'instructor_id': self.instructor_id,
            'content': self.content,
            'rubric_scores': self.rubric_scores,
            'suggestions': self.suggestions,
            'confidence_score': self.confidence_score,
            'model_used': self.model_used,
            'is_approved': self.is_approved,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }
        
        if self.approved_at:
            data['approved_at'] = self.approved_at.isoformat()
            
        return data


# Database interface (abstract base class)
class DatabaseInterface:
    """Abstract interface for database operations"""
    
    def save_course(self, course: Course) -> bool:
        raise NotImplementedError
    
    def get_course(self, course_id: str) -> Optional[Course]:
        raise NotImplementedError
    
    def get_courses_for_user(self, user_id: str) -> List[Course]:
        raise NotImplementedError
    
    def save_assignment(self, assignment: Assignment) -> bool:
        raise NotImplementedError
    
    def get_assignment(self, assignment_id: str) -> Optional[Assignment]:
        raise NotImplementedError
    
    def get_assignments_for_course(self, course_id: str) -> List[Assignment]:
        raise NotImplementedError
    
    def save_submission(self, submission: Submission) -> bool:
        raise NotImplementedError
    
    def get_submission(self, submission_id: str) -> Optional[Submission]:
        raise NotImplementedError
    
    def get_submissions_for_assignment(self, assignment_id: str) -> List[Submission]:
        raise NotImplementedError
    
    def save_reminder(self, reminder: Reminder) -> bool:
        raise NotImplementedError
    
    def get_pending_reminders(self) -> List[Reminder]:
        raise NotImplementedError
    
    def save_feedback_draft(self, feedback: FeedbackDraft) -> bool:
        raise NotImplementedError
    
    def get_feedback_draft(self, feedback_id: str) -> Optional[FeedbackDraft]:
        raise NotImplementedError


# Example usage
if __name__ == "__main__":
    # Create sample data
    course = Course(
        id="course_1",
        canvas_course_id="12345",
        name="Introduction to Computer Science",
        course_code="CS101"
    )
    
    assignment = Assignment(
        id="assign_1",
        canvas_assignment_id="67890",
        course_id="course_1",
        name="Programming Assignment 1",
        due_at=datetime.utcnow(),
        points_possible=100.0
    )
    
    print("✅ Data models created successfully")
    print(f"Course: {course.name}")
    print(f"Assignment: {assignment.name}")
    print(f"Is due soon: {assignment.is_due_soon()}")
    print(f"Is overdue: {assignment.is_overdue()}")