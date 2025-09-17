"""
Notification system for Canvas automation
Handles push notifications, email, and SMS alerts
"""

import os
import json
import smtplib
import requests
from datetime import datetime
from typing import Optional, Dict, Any, List
from dataclasses import dataclass
from enum import Enum
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from models.data_models import Reminder
from auth.auth_service import User


class NotificationType(Enum):
    PUSH = "push"
    EMAIL = "email"
    SMS = "sms"


class NotificationStatus(Enum):
    PENDING = "pending"
    SENT = "sent"
    FAILED = "failed"
    DELIVERED = "delivered"
    READ = "read"


@dataclass
class Notification:
    """Notification data model"""
    id: str
    user_id: str
    title: str
    message: str
    notification_type: NotificationType
    status: NotificationStatus = NotificationStatus.PENDING
    metadata: Dict[str, Any] = None
    sent_at: Optional[datetime] = None
    delivered_at: Optional[datetime] = None
    read_at: Optional[datetime] = None
    created_at: datetime = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.utcnow()
        if self.metadata is None:
            self.metadata = {}


class NotificationProvider:
    """Abstract base class for notification providers"""
    
    def send(self, notification: Notification) -> bool:
        raise NotImplementedError


class EmailProvider(NotificationProvider):
    """Email notification provider using SMTP"""
    
    def __init__(self, smtp_host: str, smtp_port: int, username: str, password: str):
        self.smtp_host = smtp_host
        self.smtp_port = smtp_port
        self.username = username
        self.password = password
        self.logger = logging.getLogger(__name__)
    
    def send(self, notification: Notification) -> bool:
        """Send email notification"""
        try:
            # Create message
            msg = MIMEMultipart()
            msg['From'] = self.username
            msg['To'] = notification.metadata.get('email', '')
            msg['Subject'] = notification.title
            
            # Add body
            msg.attach(MIMEText(notification.message, 'plain'))
            
            # Send email
            with smtplib.SMTP(self.smtp_host, self.smtp_port) as server:
                server.starttls()
                server.login(self.username, self.password)
                server.send_message(msg)
            
            self.logger.info(f"Email sent to {notification.metadata.get('email')}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to send email: {e}")
            return False


class PushNotificationProvider(NotificationProvider):
    """Push notification provider using Firebase Cloud Messaging"""
    
    def __init__(self, server_key: str):
        self.server_key = server_key
        self.fcm_url = "https://fcm.googleapis.com/fcm/send"
        self.logger = logging.getLogger(__name__)
    
    def send(self, notification: Notification) -> bool:
        """Send push notification via FCM"""
        try:
            device_token = notification.metadata.get('device_token')
            if not device_token:
                self.logger.error("No device token provided")
                return False
            
            headers = {
                'Authorization': f'key={self.server_key}',
                'Content-Type': 'application/json'
            }
            
            payload = {
                'to': device_token,
                'notification': {
                    'title': notification.title,
                    'body': notification.message,
                    'sound': 'default'
                },
                'data': {
                    'notification_id': notification.id,
                    'type': notification.notification_type.value
                }
            }
            
            response = requests.post(self.fcm_url, headers=headers, json=payload)
            response.raise_for_status()
            
            result = response.json()
            if result.get('success') == 1:
                self.logger.info(f"Push notification sent to {device_token}")
                return True
            else:
                self.logger.error(f"FCM error: {result}")
                return False
                
        except Exception as e:
            self.logger.error(f"Failed to send push notification: {e}")
            return False


class SMSProvider(NotificationProvider):
    """SMS notification provider using Twilio"""
    
    def __init__(self, account_sid: str, auth_token: str, from_number: str):
        self.account_sid = account_sid
        self.auth_token = auth_token
        self.from_number = from_number
        self.twilio_url = f"https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json"
        self.logger = logging.getLogger(__name__)
    
    def send(self, notification: Notification) -> bool:
        """Send SMS notification via Twilio"""
        try:
            phone_number = notification.metadata.get('phone_number')
            if not phone_number:
                self.logger.error("No phone number provided")
                return False
            
            auth = (self.account_sid, self.auth_token)
            data = {
                'From': self.from_number,
                'To': phone_number,
                'Body': f"{notification.title}: {notification.message}"
            }
            
            response = requests.post(self.twilio_url, auth=auth, data=data)
            response.raise_for_status()
            
            result = response.json()
            if result.get('status') in ['queued', 'sent']:
                self.logger.info(f"SMS sent to {phone_number}")
                return True
            else:
                self.logger.error(f"Twilio error: {result}")
                return False
                
        except Exception as e:
            self.logger.error(f"Failed to send SMS: {e}")
            return False


class NotificationService:
    """Main notification service"""
    
    def __init__(self):
        self.providers = {}
        self.logger = logging.getLogger(__name__)
        self.notifications_db = {}  # In production, use proper database
        
        # Initialize providers based on environment variables
        self._initialize_providers()
    
    def _initialize_providers(self):
        """Initialize notification providers"""
        
        # Email provider
        if all([
            os.getenv('SMTP_HOST'),
            os.getenv('SMTP_USERNAME'),
            os.getenv('SMTP_PASSWORD')
        ]):
            self.providers[NotificationType.EMAIL] = EmailProvider(
                smtp_host=os.getenv('SMTP_HOST'),
                smtp_port=int(os.getenv('SMTP_PORT', '587')),
                username=os.getenv('SMTP_USERNAME'),
                password=os.getenv('SMTP_PASSWORD')
            )
        
        # Push notification provider
        if os.getenv('FCM_SERVER_KEY'):
            self.providers[NotificationType.PUSH] = PushNotificationProvider(
                server_key=os.getenv('FCM_SERVER_KEY')
            )
        
        # SMS provider
        if all([
            os.getenv('TWILIO_ACCOUNT_SID'),
            os.getenv('TWILIO_AUTH_TOKEN'),
            os.getenv('TWILIO_FROM_NUMBER')
        ]):
            self.providers[NotificationType.SMS] = SMSProvider(
                account_sid=os.getenv('TWILIO_ACCOUNT_SID'),
                auth_token=os.getenv('TWILIO_AUTH_TOKEN'),
                from_number=os.getenv('TWILIO_FROM_NUMBER')
            )
    
    def send_notification(self, user_id: str, title: str, message: str,
                         notification_type: NotificationType = NotificationType.PUSH,
                         metadata: Dict[str, Any] = None) -> str:
        """Send notification to user"""
        
        notification = Notification(
            id=f"notif_{user_id}_{datetime.utcnow().timestamp()}",
            user_id=user_id,
            title=title,
            message=message,
            notification_type=notification_type,
            metadata=metadata or {}
        )
        
        # Store notification
        self.notifications_db[notification.id] = notification
        
        # Send notification
        provider = self.providers.get(notification_type)
        if not provider:
            self.logger.error(f"No provider available for {notification_type.value}")
            notification.status = NotificationStatus.FAILED
            return notification.id
        
        success = provider.send(notification)
        
        if success:
            notification.status = NotificationStatus.SENT
            notification.sent_at = datetime.utcnow()
        else:
            notification.status = NotificationStatus.FAILED
        
        return notification.id
    
    def send_reminder_notification(self, reminder: Reminder, user: User) -> str:
        """Send notification for a reminder"""
        
        # Determine notification type
        notification_type = NotificationType(reminder.notification_type)
        
        # Prepare metadata based on notification type
        metadata = {}
        if notification_type == NotificationType.EMAIL:
            metadata['email'] = user.email
        elif notification_type == NotificationType.PUSH:
            # TODO: Get device token from user preferences
            metadata['device_token'] = user.metadata.get('device_token', '')
        elif notification_type == NotificationType.SMS:
            # TODO: Get phone number from user preferences
            metadata['phone_number'] = user.metadata.get('phone_number', '')
        
        return self.send_notification(
            user_id=user.id,
            title="Assignment Reminder",
            message=reminder.message,
            notification_type=notification_type,
            metadata=metadata
        )
    
    def send_assignment_alert(self, user_id: str, assignment_name: str, 
                            hours_until_due: int, notification_type: NotificationType = NotificationType.PUSH) -> str:
        """Send assignment due date alert"""
        
        if hours_until_due <= 0:
            title = "Assignment Overdue"
            message = f"{assignment_name} is now overdue. Please submit as soon as possible."
        elif hours_until_due <= 1:
            title = "Assignment Due Soon"
            message = f"{assignment_name} is due in less than 1 hour!"
        elif hours_until_due <= 24:
            title = "Assignment Due Tomorrow"
            message = f"{assignment_name} is due in {hours_until_due} hours."
        else:
            title = "Assignment Reminder"
            message = f"{assignment_name} is due in {hours_until_due} hours."
        
        return self.send_notification(
            user_id=user_id,
            title=title,
            message=message,
            notification_type=notification_type
        )
    
    def send_feedback_notification(self, user_id: str, assignment_name: str, 
                                 notification_type: NotificationType = NotificationType.PUSH) -> str:
        """Send notification when feedback is available"""
        
        return self.send_notification(
            user_id=user_id,
            title="Feedback Available",
            message=f"Feedback for {assignment_name} is now available.",
            notification_type=notification_type
        )
    
    def get_notification_status(self, notification_id: str) -> Optional[NotificationStatus]:
        """Get status of a notification"""
        notification = self.notifications_db.get(notification_id)
        return notification.status if notification else None
    
    def mark_notification_read(self, notification_id: str) -> bool:
        """Mark notification as read"""
        notification = self.notifications_db.get(notification_id)
        if notification:
            notification.status = NotificationStatus.READ
            notification.read_at = datetime.utcnow()
            return True
        return False
    
    def get_user_notifications(self, user_id: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Get notifications for a user"""
        user_notifications = [
            notif for notif in self.notifications_db.values()
            if notif.user_id == user_id
        ]
        
        # Sort by creation time (newest first)
        user_notifications.sort(key=lambda x: x.created_at, reverse=True)
        
        return [notif.__dict__ for notif in user_notifications[:limit]]


# Example usage
if __name__ == "__main__":
    # Initialize notification service
    service = NotificationService()
    
    print("✅ Notification service initialized")
    print(f"Available providers: {list(service.providers.keys())}")
    
    # Test notification (if providers are configured)
    if service.providers:
        notification_id = service.send_notification(
            user_id="test_user",
            title="Test Notification",
            message="This is a test notification",
            notification_type=NotificationType.PUSH,
            metadata={'device_token': 'test_token'}
        )
        print(f"Sent notification: {notification_id}")
    else:
        print("No notification providers configured")
