"""
Canvas Assignment Submission Service
Implements assignment submission functionality for Canvas LMS
"""

import os
import requests
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime

logger = logging.getLogger(__name__)


class CanvasAssignmentSubmissionService:
    """Service for submitting assignments to Canvas"""
    
    def __init__(self, base_url: str, access_token: str):
        self.base_url = base_url.rstrip('/')
        self.access_token = access_token
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Bearer {access_token}',
            'User-Agent': 'CanvasAutomationFlow/1.0'
        })
    
    def submit_text_entry(self, course_id: str, assignment_id: str, 
                         text_content: str, comment: str = "") -> Dict[str, Any]:
        """
        Submit an assignment with text entry
        
        Args:
            course_id: Canvas course ID
            assignment_id: Canvas assignment ID
            text_content: The text content to submit
            comment: Optional comment for the submission
            
        Returns:
            Dict containing submission information
        """
        try:
            url = f"{self.base_url}/api/v1/courses/{course_id}/assignments/{assignment_id}/submissions"
            
            data = {
                'submission[submission_type]': 'online_text_entry',
                'submission[body]': text_content
            }
            
            if comment:
                data['comment[text_comment]'] = comment
            
            logger.info(f"Submitting text entry for assignment {assignment_id}")
            
            response = self.session.post(url, data=data)
            response.raise_for_status()
            
            submission_info = response.json()
            logger.info(f"Text submission successful: {submission_info.get('id')}")
            
            return submission_info
            
        except Exception as e:
            logger.error(f"Text submission failed: {e}")
            raise
    
    def submit_file_upload(self, course_id: str, assignment_id: str, 
                          file_ids: List[str], comment: str = "") -> Dict[str, Any]:
        """
        Submit an assignment with file uploads
        
        Args:
            course_id: Canvas course ID
            assignment_id: Canvas assignment ID
            file_ids: List of Canvas file IDs to submit
            comment: Optional comment for the submission
            
        Returns:
            Dict containing submission information
        """
        try:
            url = f"{self.base_url}/api/v1/courses/{course_id}/assignments/{assignment_id}/submissions"
            
            data = {
                'submission[submission_type]': 'online_upload',
                'submission[file_ids][]': file_ids
            }
            
            if comment:
                data['comment[text_comment]'] = comment
            
            logger.info(f"Submitting file upload for assignment {assignment_id} with {len(file_ids)} files")
            
            response = self.session.post(url, data=data)
            response.raise_for_status()
            
            submission_info = response.json()
            logger.info(f"File submission successful: {submission_info.get('id')}")
            
            return submission_info
            
        except Exception as e:
            logger.error(f"File submission failed: {e}")
            raise
    
    def submit_url(self, course_id: str, assignment_id: str, 
                   url_submission: str, comment: str = "") -> Dict[str, Any]:
        """
        Submit an assignment with a URL
        
        Args:
            course_id: Canvas course ID
            assignment_id: Canvas assignment ID
            url_submission: The URL to submit
            comment: Optional comment for the submission
            
        Returns:
            Dict containing submission information
        """
        try:
            url = f"{self.base_url}/api/v1/courses/{course_id}/assignments/{assignment_id}/submissions"
            
            data = {
                'submission[submission_type]': 'online_url',
                'submission[url]': url_submission
            }
            
            if comment:
                data['comment[text_comment]'] = comment
            
            logger.info(f"Submitting URL for assignment {assignment_id}: {url_submission}")
            
            response = self.session.post(url, data=data)
            response.raise_for_status()
            
            submission_info = response.json()
            logger.info(f"URL submission successful: {submission_info.get('id')}")
            
            return submission_info
            
        except Exception as e:
            logger.error(f"URL submission failed: {e}")
            raise
    
    def get_submission(self, course_id: str, assignment_id: str, 
                      user_id: str = "self") -> Dict[str, Any]:
        """
        Get submission details for an assignment
        
        Args:
            course_id: Canvas course ID
            assignment_id: Canvas assignment ID
            user_id: User ID (defaults to 'self' for current user)
            
        Returns:
            Dict containing submission information
        """
        try:
            url = f"{self.base_url}/api/v1/courses/{course_id}/assignments/{assignment_id}/submissions/{user_id}"
            
            response = self.session.get(url)
            response.raise_for_status()
            
            return response.json()
            
        except Exception as e:
            logger.error(f"Get submission failed: {e}")
            raise
    
    def add_submission_comment(self, course_id: str, assignment_id: str, 
                             user_id: str, comment: str, 
                             file_ids: Optional[List[str]] = None) -> Dict[str, Any]:
        """
        Add a comment to a submission
        
        Args:
            course_id: Canvas course ID
            assignment_id: Canvas assignment ID
            user_id: User ID
            comment: Comment text
            file_ids: Optional list of file IDs to attach
            
        Returns:
            Dict containing comment information
        """
        try:
            url = f"{self.base_url}/api/v1/courses/{course_id}/assignments/{assignment_id}/submissions/{user_id}"
            
            data = {
                'comment[text_comment]': comment
            }
            
            if file_ids:
                data['comment[file_ids][]'] = file_ids
            
            response = self.session.put(url, data=data)
            response.raise_for_status()
            
            return response.json()
            
        except Exception as e:
            logger.error(f"Add comment failed: {e}")
            raise
