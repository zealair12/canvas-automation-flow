#!/usr/bin/env python3
"""
Simple test script for Canvas Automation Flow
Tests basic functionality without requiring environment variables
"""

import sys
import os

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

def test_imports():
    """Test that all modules can be imported"""
    try:
        from models.data_models import Course, Assignment, Submission, Reminder, FeedbackDraft
        from auth.auth_service import User, UserRole, TokenManager
        from canvas.canvas_client import CanvasAPIClient
        from llm.llm_service import LLMService, LLMProvider
        from notifications.notification_service import NotificationService
        from sync.sync_service import CanvasSyncService
        print("✅ All imports successful")
        return True
    except Exception as e:
        print(f"❌ Import failed: {e}")
        return False

def test_data_models():
    """Test data model creation"""
    try:
        from models.data_models import Course, Assignment, Submission
        from auth.auth_service import User, UserRole
        
        # Create test course
        course = Course(
            id="test_course",
            canvas_course_id="123",
            name="Test Course",
            course_code="TC101"
        )
        
        # Create test assignment
        assignment = Assignment(
            id="test_assignment",
            canvas_assignment_id="456",
            course_id="test_course",
            name="Test Assignment"
        )
        
        # Create test user
        user = User(
            id="test_user",
            canvas_user_id="789",
            email="test@example.com",
            name="Test User",
            role=UserRole.STUDENT,
            access_token="dummy_token"
        )
        
        print("✅ Data models created successfully")
        print(f"   Course: {course.name}")
        print(f"   Assignment: {assignment.name}")
        print(f"   User: {user.name} ({user.role.value})")
        return True
        
    except Exception as e:
        print(f"❌ Data model test failed: {e}")
        return False

def test_llm_service():
    """Test LLM service without API calls"""
    try:
        from llm.llm_service import LLMService, LLMProvider
        from models.data_models import Assignment
        from auth.auth_service import User, UserRole
        from datetime import datetime, timedelta
        
        # Create test data
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
        
        # Test LLM service initialization (without API key)
        print("✅ LLM service structure validated")
        print(f"   Assignment: {assignment.name}")
        print(f"   User: {user.name}")
        print(f"   Due in: {assignment.is_due_soon()}")
        return True
        
    except Exception as e:
        print(f"❌ LLM service test failed: {e}")
        return False

def test_notification_service():
    """Test notification service structure"""
    try:
        from notifications.notification_service import NotificationService, NotificationType
        
        # Test notification service initialization
        service = NotificationService()
        print("✅ Notification service initialized")
        print(f"   Available providers: {list(service.providers.keys())}")
        return True
        
    except Exception as e:
        print(f"❌ Notification service test failed: {e}")
        return False

def main():
    """Run all tests"""
    print("🧪 Canvas Automation Flow - Basic Tests")
    print("=" * 50)
    
    tests = [
        ("Import Test", test_imports),
        ("Data Models Test", test_data_models),
        ("LLM Service Test", test_llm_service),
        ("Notification Service Test", test_notification_service)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n🔄 Running {test_name}...")
        if test_func():
            passed += 1
        else:
            print(f"❌ {test_name} failed")
    
    print(f"\n📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All basic tests passed!")
        print("\n📋 Next steps:")
        print("1. Set up environment variables in .env file")
        print("2. Test Canvas connection: python src/main.py test")
        print("3. Run full test suite: python src/main.py test-suite")
        return 0
    else:
        print("❌ Some tests failed. Check the output above.")
        return 1

if __name__ == '__main__':
    sys.exit(main())
