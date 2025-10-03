"""
Calendar service for generating .ics files from study plans
Integrates with study plan generation to create importable calendar events
"""

from icalendar import Calendar, Event, Alarm
from datetime import datetime, timedelta
from typing import Dict, Any, List
import logging
import os

logger = logging.getLogger(__name__)


class CalendarService:
    """Generate calendar events for study plans"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
    
    def create_ics_from_study_plan(
        self, 
        study_plan: Dict[str, Any],
        user_email: str = None
    ) -> str:
        """
        Generate .ics file from study plan
        
        Args:
            study_plan: Study plan dictionary with tasks
            user_email: User's email for calendar organizer
        
        Returns:
            Path to generated .ics file
        """
        try:
            cal = Calendar()
            cal.add('prodid', '-//Canvas Automation Flow//Study Plan//')
            cal.add('version', '2.0')
            cal.add('method', 'PUBLISH')
            cal.add('calscale', 'GREGORIAN')
            
            # Extract tasks from study plan
            tasks = self._extract_tasks_from_plan(study_plan)
            
            for task in tasks:
                event = Event()
                event.add('summary', task.get('title', 'Study Task'))
                event.add('description', task.get('description', ''))
                event.add('dtstart', task.get('start_time'))
                event.add('dtend', task.get('end_time'))
                event.add('location', 'Canvas LMS')
                event.add('status', 'CONFIRMED')
                event.add('uid', f"{task.get('id', 'task')}@canvasautomation.com")
                
                # Add organizer if email provided
                if user_email:
                    event.add('organizer', f'mailto:{user_email}')
                
                # Add reminder 1 hour before
                alarm = Alarm()
                alarm.add('trigger', timedelta(hours=-1))
                alarm.add('action', 'DISPLAY')
                alarm.add('description', f"Reminder: {task.get('title', 'Study Task')}")
                event.add_component(alarm)
                
                cal.add_component(event)
            
            # Write to file
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"study_plan_{timestamp}.ics"
            filepath = os.path.join('/tmp', filename)
            
            with open(filepath, 'wb') as f:
                f.write(cal.to_ical())
            
            self.logger.info(f"Generated calendar file: {filepath}")
            return filepath
            
        except Exception as e:
            self.logger.error(f"Error generating calendar: {e}")
            raise
    
    def _extract_tasks_from_plan(self, study_plan: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Extract tasks from study plan content"""
        tasks = []
        
        # Try to find tasks in various formats
        if 'tasks' in study_plan:
            tasks = study_plan['tasks']
        elif 'schedule' in study_plan:
            tasks = study_plan['schedule']
        elif 'assignments' in study_plan:
            # Convert assignments to tasks
            for assignment in study_plan['assignments']:
                task = {
                    'id': assignment.get('id', ''),
                    'title': f"Study: {assignment.get('name', 'Assignment')}",
                    'description': assignment.get('description', ''),
                    'start_time': self._parse_datetime(assignment.get('due_at')),
                    'end_time': self._parse_datetime(assignment.get('due_at')) + timedelta(hours=2)
                }
                tasks.append(task)
        else:
            # Parse from text content
            tasks = self._parse_tasks_from_text(study_plan.get('content', ''))
        
        return tasks
    
    def _parse_datetime(self, date_str: str) -> datetime:
        """Parse datetime from string"""
        if not date_str:
            return datetime.now()
        
        try:
            # Try ISO format
            if 'T' in date_str:
                date_str = date_str.replace('Z', '+00:00')
                return datetime.fromisoformat(date_str)
            else:
                return datetime.strptime(date_str, '%Y-%m-%d %H:%M:%S')
        except:
            return datetime.now()
    
    def _parse_tasks_from_text(self, content: str) -> List[Dict[str, Any]]:
        """Parse tasks from text content"""
        tasks = []
        lines = content.split('\n')
        
        current_task = None
        for line in lines:
            line = line.strip()
            
            # Look for task indicators
            if any(indicator in line.lower() for indicator in ['day ', 'week ', 'study ', 'review ']):
                if current_task:
                    tasks.append(current_task)
                
                current_task = {
                    'id': f"task_{len(tasks)}",
                    'title': line[:100],  # Limit title length
                    'description': '',
                    'start_time': datetime.now() + timedelta(days=len(tasks)),
                    'end_time': datetime.now() + timedelta(days=len(tasks), hours=2)
                }
            elif current_task and line:
                current_task['description'] += line + '\n'
        
        if current_task:
            tasks.append(current_task)
        
        return tasks
    
    def create_calendar_events_from_assignments(
        self,
        assignments: List[Dict[str, Any]],
        user_email: str = None
    ) -> str:
        """
        Create calendar events directly from assignments
        
        Args:
            assignments: List of assignment dictionaries
            user_email: User's email
        
        Returns:
            Path to generated .ics file
        """
        cal = Calendar()
        cal.add('prodid', '-//Canvas Automation Flow//Assignments//')
        cal.add('version', '2.0')
        
        for assignment in assignments:
            if not assignment.get('due_at'):
                continue
            
            event = Event()
            event.add('summary', assignment.get('name', 'Assignment'))
            event.add('description', assignment.get('description', ''))
            
            due_date = self._parse_datetime(assignment.get('due_at'))
            event.add('dtstart', due_date - timedelta(hours=2))  # Start 2 hours before
            event.add('dtend', due_date)
            event.add('status', 'CONFIRMED')
            event.add('uid', f"{assignment.get('id')}@canvasautomation.com")
            
            # Add alarm 24 hours before
            alarm = Alarm()
            alarm.add('trigger', timedelta(hours=-24))
            alarm.add('action', 'DISPLAY')
            alarm.add('description', f"Due tomorrow: {assignment.get('name')}")
            event.add_component(alarm)
            
            cal.add_component(event)
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"assignments_{timestamp}.ics"
        filepath = os.path.join('/tmp', filename)
        
        with open(filepath, 'wb') as f:
            f.write(cal.to_ical())
        
        return filepath

