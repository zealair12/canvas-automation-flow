"""
Authentication service for Canvas OAuth2 integration
Handles token management, user roles, and secure storage
"""

import os
import json
import hashlib
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from dataclasses import dataclass, asdict
from enum import Enum
import requests
from cryptography.fernet import Fernet


class UserRole(Enum):
    STUDENT = "student"
    INSTRUCTOR = "instructor"
    ADMIN = "admin"


@dataclass
class User:
    """User data model"""
    id: str
    canvas_user_id: str
    email: str
    name: str
    role: UserRole
    access_token: str
    refresh_token: Optional[str] = None
    token_expires_at: Optional[datetime] = None
    created_at: datetime = None
    last_login: Optional[datetime] = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.utcnow()


class TokenManager:
    """Handles secure token storage and encryption"""
    
    def __init__(self, encryption_key: Optional[str] = None):
        if encryption_key:
            self.cipher = Fernet(encryption_key.encode())
        else:
            # Generate a new key if none provided
            key = Fernet.generate_key()
            self.cipher = Fernet(key)
            print(f"Generated encryption key: {key.decode()}")
    
    def encrypt_token(self, token: str) -> str:
        """Encrypt a token for secure storage"""
        return self.cipher.encrypt(token.encode()).decode()
    
    def decrypt_token(self, encrypted_token: str) -> str:
        """Decrypt a token for use"""
        return self.cipher.decrypt(encrypted_token.encode()).decode()


class CanvasAuthService:
    """Canvas OAuth2 authentication service"""
    
    def __init__(self, canvas_base_url: str, client_id: str, client_secret: str, 
                 redirect_uri: str, token_manager: TokenManager):
        self.canvas_base_url = canvas_base_url.rstrip('/')
        self.client_id = client_id
        self.client_secret = client_secret
        self.redirect_uri = redirect_uri
        self.token_manager = token_manager
        self.users_db = {}  # In production, use proper database
    
    def get_authorization_url(self, state: str = None) -> str:
        """Generate Canvas OAuth2 authorization URL"""
        if not state:
            state = hashlib.sha256(os.urandom(32)).hexdigest()
        
        params = {
            'client_id': self.client_id,
            'response_type': 'code',
            'redirect_uri': self.redirect_uri,
            'scope': 'url:GET|/api/v1/users/self,url:GET|/api/v1/courses,url:GET|/api/v1/assignments',
            'state': state
        }
        
        query_string = '&'.join([f"{k}={v}" for k, v in params.items()])
        return f"{self.canvas_base_url}/login/oauth2/auth?{query_string}"
    
    def exchange_code_for_token(self, code: str, state: str = None) -> Dict[str, Any]:
        """Exchange authorization code for access token"""
        url = f"{self.canvas_base_url}/login/oauth2/token"
        
        data = {
            'grant_type': 'authorization_code',
            'client_id': self.client_id,
            'client_secret': self.client_secret,
            'redirect_uri': self.redirect_uri,
            'code': code
        }
        
        try:
            response = requests.post(url, data=data)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"❌ Token exchange failed: {e}")
            return None
    
    def refresh_access_token(self, refresh_token: str) -> Dict[str, Any]:
        """Refresh an expired access token"""
        url = f"{self.canvas_base_url}/login/oauth2/token"
        
        data = {
            'grant_type': 'refresh_token',
            'client_id': self.client_id,
            'client_secret': self.client_secret,
            'refresh_token': refresh_token
        }
        
        try:
            response = requests.post(url, data=data)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"❌ Token refresh failed: {e}")
            return None
    
    def get_user_info(self, access_token: str) -> Dict[str, Any]:
        """Get user information from Canvas"""
        url = f"{self.canvas_base_url}/api/v1/users/self"
        headers = {'Authorization': f'Bearer {access_token}'}
        
        try:
            response = requests.get(url, headers=headers)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"❌ Failed to get user info: {e}")
            return None
    
    def determine_user_role(self, user_info: Dict[str, Any], access_token: str) -> UserRole:
        """Determine user role based on Canvas data"""
        # Check if user is an instructor by looking at courses they teach
        courses_url = f"{self.canvas_base_url}/api/v1/courses"
        headers = {'Authorization': f'Bearer {access_token}'}
        
        try:
            response = requests.get(courses_url, headers=headers, 
                                 params={'enrollment_type': 'teacher'})
            if response.status_code == 200:
                teacher_courses = response.json()
                if teacher_courses:
                    return UserRole.INSTRUCTOR
            
            # Check for admin role (this would need specific Canvas permissions)
            if user_info.get('permissions', {}).get('can_create_courses'):
                return UserRole.ADMIN
                
        except requests.exceptions.RequestException:
            pass
        
        return UserRole.STUDENT
    
    def authenticate_user(self, code: str, state: str = None) -> Optional[User]:
        """Complete OAuth2 flow and create user"""
        # Exchange code for token
        token_data = self.exchange_code_for_token(code, state)
        if not token_data:
            return None
        
        access_token = token_data['access_token']
        refresh_token = token_data.get('refresh_token')
        expires_in = token_data.get('expires_in', 3600)
        
        # Get user info
        user_info = self.get_user_info(access_token)
        if not user_info:
            return None
        
        # Determine role
        role = self.determine_user_role(user_info, access_token)
        
        # Create user
        user = User(
            id=user_info['id'],
            canvas_user_id=str(user_info['id']),
            email=user_info.get('email', ''),
            name=user_info.get('name', ''),
            role=role,
            access_token=self.token_manager.encrypt_token(access_token),
            refresh_token=self.token_manager.encrypt_token(refresh_token) if refresh_token else None,
            token_expires_at=datetime.utcnow() + timedelta(seconds=expires_in),
            last_login=datetime.utcnow()
        )
        
        # Store user
        self.users_db[user.id] = user
        return user
    
    def get_user(self, user_id: str) -> Optional[User]:
        """Get user by ID"""
        return self.users_db.get(user_id)
    
    def get_user_by_token(self, access_token: str) -> Optional[User]:
        """Get user by access token"""
        for user in self.users_db.values():
            if self.token_manager.decrypt_token(user.access_token) == access_token:
                return user
        return None
    
    def is_token_valid(self, user: User) -> bool:
        """Check if user's token is still valid"""
        if not user.token_expires_at:
            return True  # No expiration set
        
        return datetime.utcnow() < user.token_expires_at
    
    def refresh_user_token(self, user: User) -> bool:
        """Refresh user's access token if needed"""
        if self.is_token_valid(user):
            return True
        
        if not user.refresh_token:
            return False
        
        refresh_token = self.token_manager.decrypt_token(user.refresh_token)
        token_data = self.refresh_access_token(refresh_token)
        
        if not token_data:
            return False
        
        # Update user with new token
        user.access_token = self.token_manager.encrypt_token(token_data['access_token'])
        if token_data.get('refresh_token'):
            user.refresh_token = self.token_manager.encrypt_token(token_data['refresh_token'])
        
        expires_in = token_data.get('expires_in', 3600)
        user.token_expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
        
        return True


# Example usage and testing
if __name__ == "__main__":
    # Initialize services
    token_manager = TokenManager()
    auth_service = CanvasAuthService(
        canvas_base_url=os.getenv("CANVAS_BASE_URL", "https://your-school.instructure.com"),
        client_id=os.getenv("CANVAS_CLIENT_ID", ""),
        client_secret=os.getenv("CANVAS_CLIENT_SECRET", ""),
        redirect_uri=os.getenv("CANVAS_REDIRECT_URI", "http://localhost:8000/auth/callback"),
        token_manager=token_manager
    )
    
    print("✅ Authentication service initialized")
    print(f"Authorization URL: {auth_service.get_authorization_url()}")
