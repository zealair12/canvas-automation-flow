"""
Canvas API client with rate limiting, error handling, and caching
Provides a robust interface to Canvas LMS API endpoints
"""

import time
import json
import requests
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List, Generator
from dataclasses import dataclass
from enum import Enum
import logging
from urllib.parse import urljoin, urlparse, parse_qs


class CanvasAPIError(Exception):
    """Base exception for Canvas API errors"""
    pass


class RateLimitError(CanvasAPIError):
    """Raised when rate limit is exceeded"""
    pass


class AuthenticationError(CanvasAPIError):
    """Raised when authentication fails"""
    pass


class NotFoundError(CanvasAPIError):
    """Raised when resource is not found"""
    pass


@dataclass
class RateLimitInfo:
    """Rate limit information"""
    limit: int
    remaining: int
    reset_time: datetime
    
    def is_exceeded(self) -> bool:
        return self.remaining <= 0
    
    def time_until_reset(self) -> timedelta:
        return self.reset_time - datetime.utcnow()


class CanvasAPIClient:
    """Robust Canvas API client with rate limiting and error handling"""
    
    def __init__(self, base_url: str, access_token: str, 
                 rate_limit_buffer: int = 10, timeout: int = 30):
        self.base_url = base_url.rstrip('/')
        self.access_token = access_token
        self.rate_limit_buffer = rate_limit_buffer
        self.timeout = timeout
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Bearer {access_token}',
            'Content-Type': 'application/json',
            'User-Agent': 'Canvas-Automation-Flow/1.0'
        })
        
        # Rate limiting
        self.rate_limit_info = None
        self.last_request_time = 0
        self.min_request_interval = 0.1  # Minimum 100ms between requests
        
        # Caching
        self.cache = {}
        self.cache_ttl = 300  # 5 minutes default TTL
        
        # Logging
        self.logger = logging.getLogger(__name__)
    
    def _make_request(self, method: str, endpoint: str, **kwargs) -> requests.Response:
        """Make a rate-limited request to Canvas API"""
        # Rate limiting
        current_time = time.time()
        time_since_last = current_time - self.last_request_time
        if time_since_last < self.min_request_interval:
            time.sleep(self.min_request_interval - time_since_last)
        
        # Check rate limits
        if self.rate_limit_info and self.rate_limit_info.is_exceeded():
            wait_time = self.rate_limit_info.time_until_reset().total_seconds()
            if wait_time > 0:
                self.logger.warning(f"Rate limit exceeded, waiting {wait_time:.1f} seconds")
                time.sleep(wait_time)
        
        # Make request
        url = urljoin(self.base_url, f"/api/v1/{endpoint.lstrip('/')}")
        self.last_request_time = time.time()
        
        try:
            response = self.session.request(method, url, timeout=self.timeout, **kwargs)
            
            # Update rate limit info
            self._update_rate_limit_info(response)
            
            # Handle errors
            if response.status_code == 401:
                raise AuthenticationError("Invalid or expired access token")
            elif response.status_code == 404:
                raise NotFoundError(f"Resource not found: {endpoint}")
            elif response.status_code == 429:
                raise RateLimitError("Rate limit exceeded")
            elif not response.ok:
                raise CanvasAPIError(f"API error {response.status_code}: {response.text}")
            
            return response
            
        except requests.exceptions.Timeout:
            raise CanvasAPIError("Request timeout")
        except requests.exceptions.ConnectionError:
            raise CanvasAPIError("Connection error")
        except requests.exceptions.RequestException as e:
            raise CanvasAPIError(f"Request failed: {e}")
    
    def _update_rate_limit_info(self, response: requests.Response):
        """Update rate limit information from response headers"""
        try:
            limit = response.headers.get('X-Rate-Limit-Limit')
            remaining = response.headers.get('X-Rate-Limit-Remaining')
            reset = response.headers.get('X-Rate-Limit-Reset')
            
            if all([limit, remaining, reset]):
                self.rate_limit_info = RateLimitInfo(
                    limit=int(limit),
                    remaining=int(remaining),
                    reset_time=datetime.fromtimestamp(int(reset))
                )
        except (ValueError, TypeError):
            pass
    
    def _get_cached(self, key: str) -> Optional[Any]:
        """Get cached data if not expired"""
        if key in self.cache:
            data, timestamp = self.cache[key]
            if datetime.utcnow() - timestamp < timedelta(seconds=self.cache_ttl):
                return data
            else:
                del self.cache[key]
        return None
    
    def _set_cache(self, key: str, data: Any):
        """Cache data with timestamp"""
        self.cache[key] = (data, datetime.utcnow())
    
    def get_user_info(self) -> Dict[str, Any]:
        """Get current user information"""
        cache_key = "user_info"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        response = self._make_request('GET', 'users/self')
        data = response.json()
        self._set_cache(cache_key, data)
        return data
    
    def get_courses(self, enrollment_type: str = None, 
                   enrollment_role: str = None) -> List[Dict[str, Any]]:
        """Get courses for current user"""
        cache_key = f"courses_{enrollment_type}_{enrollment_role}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        params = {}
        if enrollment_type:
            params['enrollment_type'] = enrollment_type
        if enrollment_role:
            params['enrollment_role'] = enrollment_role
        
        response = self._make_request('GET', 'courses', params=params)
        data = response.json()
        self._set_cache(cache_key, data)
        return data
    
    def get_course(self, course_id: str) -> Dict[str, Any]:
        """Get specific course details"""
        cache_key = f"course_{course_id}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        response = self._make_request('GET', f'courses/{course_id}')
        data = response.json()
        self._set_cache(cache_key, data)
        return data
    
    def get_assignments(self, course_id: str, 
                       assignment_ids: List[str] = None) -> List[Dict[str, Any]]:
        """Get assignments for a course"""
        cache_key = f"assignments_{course_id}_{assignment_ids}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        params = {}
        if assignment_ids:
            params['assignment_ids[]'] = assignment_ids
        
        response = self._make_request('GET', f'courses/{course_id}/assignments', params=params)
        data = response.json()
        self._set_cache(cache_key, data)
        return data
    
    def get_assignment(self, course_id: str, assignment_id: str) -> Dict[str, Any]:
        """Get specific assignment details"""
        cache_key = f"assignment_{course_id}_{assignment_id}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        response = self._make_request('GET', f'courses/{course_id}/assignments/{assignment_id}')
        data = response.json()
        self._set_cache(cache_key, data)
        return data
    
    def get_assignment_details(self, assignment_id: str) -> Dict[str, Any]:
        """Get specific assignment details by ID only"""
        cache_key = f"assignment_details_{assignment_id}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        # Use assignments endpoint directly with assignment ID
        response = self._make_request('GET', f'assignments/{assignment_id}')
        data = response.json()
        self._set_cache(cache_key, data)
        return data
    
    def get_submissions(self, course_id: str, assignment_id: str,
                       student_ids: List[str] = None) -> List[Dict[str, Any]]:
        """Get submissions for an assignment"""
        cache_key = f"submissions_{course_id}_{assignment_id}_{student_ids}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        params = {}
        if student_ids:
            params['student_ids[]'] = student_ids
        
        response = self._make_request('GET', 
                                   f'courses/{course_id}/assignments/{assignment_id}/submissions',
                                   params=params)
        data = response.json()
        self._set_cache(cache_key, data)
        return data
    
    def get_student_submissions(self, course_id: str, 
                               student_ids: List[str] = None) -> List[Dict[str, Any]]:
        """Get all submissions for students in a course"""
        cache_key = f"student_submissions_{course_id}_{student_ids}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        params = {}
        if student_ids:
            params['student_ids[]'] = student_ids
        
        response = self._make_request('GET', f'courses/{course_id}/students/submissions', params=params)
        data = response.json()
        self._set_cache(cache_key, data)
        return data
    
    def get_enrollments(self, course_id: str, 
                       enrollment_type: str = None) -> List[Dict[str, Any]]:
        """Get enrollments for a course"""
        cache_key = f"enrollments_{course_id}_{enrollment_type}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        params = {}
        if enrollment_type:
            params['type[]'] = enrollment_type
        
        response = self._make_request('GET', f'courses/{course_id}/enrollments', params=params)
        data = response.json()
        self._set_cache(cache_key, data)
        return data
    
    def get_users(self, course_id: str, 
                 enrollment_type: str = None) -> List[Dict[str, Any]]:
        """Get users enrolled in a course"""
        cache_key = f"users_{course_id}_{enrollment_type}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        params = {}
        if enrollment_type:
            params['enrollment_type[]'] = enrollment_type
        
        response = self._make_request('GET', f'courses/{course_id}/users', params=params)
        data = response.json()
        self._set_cache(cache_key, data)
        return data
    
    def create_submission(self, course_id: str, assignment_id: str,
                         submission_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a submission"""
        response = self._make_request('POST', 
                                    f'courses/{course_id}/assignments/{assignment_id}/submissions',
                                    json=submission_data)
        return response.json()
    
    def update_submission(self, course_id: str, assignment_id: str, user_id: str,
                         submission_data: Dict[str, Any]) -> Dict[str, Any]:
        """Update a submission"""
        response = self._make_request('PUT', 
                                    f'courses/{course_id}/assignments/{assignment_id}/submissions/{user_id}',
                                    json=submission_data)
        return response.json()
    
    def get_rubric(self, course_id: str, assignment_id: str) -> Optional[Dict[str, Any]]:
        """Get rubric for an assignment"""
        cache_key = f"rubric_{course_id}_{assignment_id}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        try:
            response = self._make_request('GET', f'courses/{course_id}/assignments/{assignment_id}/rubric')
            data = response.json()
            self._set_cache(cache_key, data)
            return data
        except NotFoundError:
            return None
    
    def get_files(self, course_id: str, folder_id: str = None) -> List[Dict[str, Any]]:
        """Get files for a course"""
        cache_key = f"files_{course_id}_{folder_id}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        endpoint = f'courses/{course_id}/files'
        params = {}
        if folder_id:
            params['folder_id'] = folder_id
        
        response = self._make_request('GET', endpoint, params=params)
        data = response.json()
        self._set_cache(cache_key, data)
        return data
    
    def get_file(self, course_id: str, file_id: str) -> Dict[str, Any]:
        """Get specific file details"""
        cache_key = f"file_{course_id}_{file_id}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        response = self._make_request('GET', f'courses/{course_id}/files/{file_id}')
        data = response.json()
        self._set_cache(cache_key, data)
        return data
    
    def get_folders(self, course_id: str) -> List[Dict[str, Any]]:
        """Get folders for a course"""
        cache_key = f"folders_{course_id}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        response = self._make_request('GET', f'courses/{course_id}/folders')
        data = response.json()
        self._set_cache(cache_key, data)
        return data
    
    def get_user_submissions(self, course_id: str, user_id: str = 'self') -> List[Dict[str, Any]]:
        """Get submissions for current user"""
        cache_key = f"user_submissions_{course_id}_{user_id}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        endpoint = f'courses/{course_id}/students/submissions'
        params = {'student_ids[]': ['self']} if user_id == 'self' else {'student_ids[]': [user_id]}
        
        response = self._make_request('GET', endpoint, params=params)
        data = response.json()
        self._set_cache(cache_key, data)
        return data
    
    def paginate_all(self, endpoint: str, **params) -> Generator[Dict[str, Any], None, None]:
        """Paginate through all results for an endpoint"""
        page = 1
        per_page = 100
        
        while True:
            params['page'] = page
            params['per_page'] = per_page
            
            response = self._make_request('GET', endpoint, params=params)
            data = response.json()
            
            if not data:
                break
            
            for item in data:
                yield item
            
            # Check if there are more pages
            links = response.headers.get('Link', '')
            if 'rel="next"' not in links:
                break
            
            page += 1
    
    def clear_cache(self):
        """Clear all cached data"""
        self.cache.clear()
    
    def set_cache_ttl(self, ttl_seconds: int):
        """Set cache TTL in seconds"""
        self.cache_ttl = ttl_seconds


# Example usage and testing
if __name__ == "__main__":
    import os
    from dotenv import load_dotenv
    
    load_dotenv()
    
    # Initialize client
    client = CanvasAPIClient(
        base_url=os.getenv("CANVAS_BASE_URL"),
        access_token=os.getenv("CANVAS_ACCESS_TOKEN")
    )
    
    try:
        # Test basic functionality
        user_info = client.get_user_info()
        print(f"✅ Connected as: {user_info.get('name', 'Unknown')}")
        
        courses = client.get_courses()
        print(f"✅ Found {len(courses)} courses")
        
        if courses:
            course_id = courses[0]['id']
            assignments = client.get_assignments(course_id)
            print(f"✅ Found {len(assignments)} assignments in first course")
        
    except Exception as e:
        print(f"❌ Error: {e}")