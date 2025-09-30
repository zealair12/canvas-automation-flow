"""
Enhanced Study Plan Service
Integrates grades, syllabus, and calendar for intelligent study planning
"""

import os
import requests
import logging
from typing import Dict, Any, Optional, List, Tuple
from datetime import datetime, timedelta
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass
class GradeInfo:
    """Grade information for an assignment"""
    assignment_id: str
    assignment_name: str
    score: Optional[float]
    points_possible: float
    grade: Optional[str]
    submitted_at: Optional[str]
    graded_at: Optional[str]


@dataclass
class SyllabusInfo:
    """Syllabus information"""
    course_id: str
    content: str
    grading_policy: str
    schedule: str
    important_dates: List[str]


@dataclass
class CalendarEvent:
    """Calendar event for study plan"""
    title: str
    start_time: datetime
    end_time: datetime
    description: str
    course_id: str
    assignment_id: Optional[str] = None
    event_type: str = "study"  # study, assignment, exam, break


class EnhancedStudyPlanService:
    """Enhanced study plan service with grades, syllabus, and calendar integration"""
    
    def __init__(self, base_url: str, access_token: str):
        self.base_url = base_url.rstrip('/')
        self.access_token = access_token
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Bearer {access_token}',
            'User-Agent': 'CanvasAutomationFlow/1.0'
        })
    
    def get_grades_for_course(self, course_id: str) -> List[GradeInfo]:
        """Get grade information for a course"""
        try:
            url = f"{self.base_url}/api/v1/courses/{course_id}/enrollments"
            response = self.session.get(url)

            # Handle 403 errors gracefully - course access restricted
            if response.status_code == 403:
                logger.warning(f"Cannot access enrollments for course {course_id}: Access forbidden")
                return []

            response.raise_for_status()

            enrollments = response.json()
            user_enrollment = None
            for enrollment in enrollments:
                if enrollment.get('type') == 'StudentEnrollment':
                    user_enrollment = enrollment
                    break
            
            if not user_enrollment:
                return []
            
            # Get assignment grades
            url = f"{self.base_url}/api/v1/courses/{course_id}/assignments"
            response = self.session.get(url)
            response.raise_for_status()
            
            assignments = response.json()
            grades = []
            
            for assignment in assignments:
                # Get submission for this assignment
                submission_url = f"{self.base_url}/api/v1/courses/{course_id}/assignments/{assignment['id']}/submissions/self"
                try:
                    sub_response = self.session.get(submission_url)
                    if sub_response.status_code == 200:
                        submission = sub_response.json()
                        grade_info = GradeInfo(
                            assignment_id=str(assignment['id']),
                            assignment_name=assignment.get('name', ''),
                            score=submission.get('score'),
                            points_possible=assignment.get('points_possible', 0),
                            grade=submission.get('grade'),
                            submitted_at=submission.get('submitted_at'),
                            graded_at=submission.get('graded_at')
                        )
                        grades.append(grade_info)
                except Exception as e:
                    logger.warning(f"Could not get grade for assignment {assignment['id']}: {e}")
                    continue
            
            return grades
            
        except Exception as e:
            logger.error(f"Error getting grades for course {course_id}: {e}")
            return []
    
    def get_syllabus_info(self, course_id: str) -> Optional[SyllabusInfo]:
        """Get syllabus information for a course"""
        try:
            url = f"{self.base_url}/api/v1/courses/{course_id}"
            response = self.session.get(url)

            # Handle 403 errors gracefully - course access restricted
            if response.status_code == 403:
                logger.warning(f"Cannot access course {course_id} for syllabus: Access forbidden")
                return None

            response.raise_for_status()
            
            course_data = response.json()
            syllabus_content = course_data.get('syllabus_body', '')
            
            # Extract key information from syllabus
            grading_policy = self._extract_grading_policy(syllabus_content)
            schedule = self._extract_schedule(syllabus_content)
            important_dates = self._extract_important_dates(syllabus_content)
            
            return SyllabusInfo(
                course_id=course_id,
                content=syllabus_content,
                grading_policy=grading_policy,
                schedule=schedule,
                important_dates=important_dates
            )
            
        except Exception as e:
            logger.error(f"Error getting syllabus for course {course_id}: {e}")
            return None
    
    def _extract_grading_policy(self, syllabus_content: str) -> str:
        """Extract grading policy from syllabus"""
        # Simple keyword extraction - could be enhanced with NLP
        keywords = ['grading', 'grade', 'points', 'percentage', 'weight', 'rubric']
        lines = syllabus_content.split('\n')
        
        grading_lines = []
        for line in lines:
            if any(keyword in line.lower() for keyword in keywords):
                grading_lines.append(line.strip())
        
        return '\n'.join(grading_lines[:5])  # Limit to first 5 relevant lines
    
    def _extract_schedule(self, syllabus_content: str) -> str:
        """Extract schedule information from syllabus"""
        keywords = ['schedule', 'calendar', 'timeline', 'due', 'deadline', 'week']
        lines = syllabus_content.split('\n')
        
        schedule_lines = []
        for line in lines:
            if any(keyword in line.lower() for keyword in keywords):
                schedule_lines.append(line.strip())
        
        return '\n'.join(schedule_lines[:10])  # Limit to first 10 relevant lines
    
    def _extract_important_dates(self, syllabus_content: str) -> List[str]:
        """Extract important dates from syllabus"""
        # Simple date pattern matching
        import re
        date_pattern = r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b|\b\w+ \d{1,2},? \d{4}\b'
        dates = re.findall(date_pattern, syllabus_content)
        return dates[:10]  # Limit to first 10 dates
    
    def create_calendar_events(self, assignments: List[Any], study_plan: str) -> List[CalendarEvent]:
        """Create calendar events from study plan"""
        events = []
        
        # Parse study plan to extract study sessions
        lines = study_plan.split('\n')
        current_date = None
        
        for line in lines:
            line = line.strip()
            
            # Look for date headers
            if line.startswith('##') and any(day in line.lower() for day in ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']):
                current_date = self._parse_date_from_header(line)
            
            # Look for study tasks
            elif line.startswith('-') and current_date is not None:
                event = self._create_event_from_task(line, current_date, assignments)
                if event:
                    events.append(event)
        
        return events
    
    def _parse_date_from_header(self, header: str) -> Optional[datetime]:
        """Parse date from study plan header"""
        # Simple date parsing - could be enhanced
        import re
        date_pattern = r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b'
        match = re.search(date_pattern, header)
        if match:
            try:
                date_str = match.group()
                return datetime.strptime(date_str, '%m/%d/%Y')
            except:
                pass
        return None
    
    def _create_event_from_task(self, task_line: str, date: datetime, assignments: List[Any]) -> Optional[CalendarEvent]:
        """Create calendar event from study task"""
        if date is None:
            return None
            
        # Extract time and description from task
        import re
        
        # Look for time patterns
        time_pattern = r'\b\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\b'
        time_match = re.search(time_pattern, task_line)
        
        start_time = date.replace(hour=9, minute=0)  # Default to 9 AM
        if time_match:
            try:
                time_str = time_match.group()
                start_time = datetime.strptime(f"{date.strftime('%Y-%m-%d')} {time_str}", '%Y-%m-%d %I:%M %p')
            except:
                pass
        
        # Extract assignment name if mentioned
        assignment_id = None
        for assignment in assignments:
            if hasattr(assignment, 'name') and assignment.name.lower() in task_line.lower():
                assignment_id = assignment.canvas_assignment_id
                break
        
        return CalendarEvent(
            title=task_line.replace('-', '').strip(),
            start_time=start_time,
            end_time=start_time + timedelta(hours=2),  # Default 2-hour study session
            description=task_line,
            course_id=assignments[0].course_id if assignments and hasattr(assignments[0], 'course_id') else '',
            assignment_id=assignment_id,
            event_type="study"
        )
    
    def generate_enhanced_study_plan(self, course_ids: List[str], days_ahead: int = 7) -> Dict[str, Any]:
        """Generate enhanced study plan with grades, syllabus, and calendar"""
        try:
            all_assignments = []
            all_grades = []
            syllabus_info = []
            
            # Collect data from all courses
            for course_id in course_ids:
                try:
                    # Get assignments
                    url = f"{self.base_url}/api/v1/courses/{course_id}/assignments"
                    response = self.session.get(url)
                    if response.status_code == 200:
                        assignments_data = response.json()
                        for assignment_data in assignments_data:
                            all_assignments.append(assignment_data)

                    # Get grades
                    grades = self.get_grades_for_course(course_id)
                    all_grades.extend(grades)

                    # Get syllabus
                    syllabus = self.get_syllabus_info(course_id)
                    if syllabus:
                        syllabus_info.append(syllabus)

                except Exception as e:
                    logger.warning(f"Skipping course {course_id} due to access restrictions: {e}")
                    continue
            
            # Analyze performance patterns
            performance_analysis = self._analyze_performance(all_grades)
            
            # Generate study plan
            study_plan = self._generate_smart_study_plan(
                all_assignments, 
                all_grades, 
                syllabus_info, 
                performance_analysis, 
                days_ahead
            )
            
            # Create calendar events
            calendar_events = self.create_calendar_events(all_assignments, study_plan)
            
            return {
                'study_plan': study_plan,
                'performance_analysis': performance_analysis,
                'calendar_events': [
                    {
                        'title': event.title,
                        'start_time': event.start_time.isoformat(),
                        'end_time': event.end_time.isoformat(),
                        'description': event.description,
                        'course_id': event.course_id,
                        'assignment_id': event.assignment_id,
                        'event_type': event.event_type
                    }
                    for event in calendar_events
                ],
                'syllabus_insights': [
                    {
                        'course_id': syllabus.course_id,
                        'grading_policy': syllabus.grading_policy,
                        'important_dates': syllabus.important_dates
                    }
                    for syllabus in syllabus_info
                ]
            }
            
        except Exception as e:
            logger.error(f"Error generating enhanced study plan: {e}")
            return {'error': str(e)}
    
    def _analyze_performance(self, grades: List[GradeInfo]) -> Dict[str, Any]:
        """Analyze student performance patterns"""
        if not grades:
            return {'message': 'No grade data available'}
        
        completed_grades = [g for g in grades if g.score is not None]
        if not completed_grades:
            return {'message': 'No completed assignments'}
        
        scores = [g.score for g in completed_grades]
        points_possible = [g.points_possible for g in completed_grades]
        
        # Calculate performance metrics
        total_points_earned = sum(scores)
        total_points_possible = sum(points_possible)
        overall_percentage = (total_points_earned / total_points_possible * 100) if total_points_possible > 0 else 0
        
        # Identify weak areas
        weak_assignments = [g for g in completed_grades if g.score / g.points_possible < 0.7]
        
        return {
            'overall_percentage': round(overall_percentage, 1),
            'total_assignments': len(completed_grades),
            'weak_areas': [g.assignment_name for g in weak_assignments],
            'recent_trend': self._calculate_trend(completed_grades),
            'recommendations': self._generate_recommendations(completed_grades, weak_assignments)
        }
    
    def _calculate_trend(self, grades: List[GradeInfo]) -> str:
        """Calculate performance trend"""
        if len(grades) < 2:
            return "Insufficient data"
        
        # Sort by graded_at date
        sorted_grades = sorted(grades, key=lambda g: g.graded_at or '')
        recent_scores = [g.score / g.points_possible for g in sorted_grades[-3:]]
        
        if len(recent_scores) < 2:
            return "Insufficient recent data"
        
        if recent_scores[-1] > recent_scores[0]:
            return "Improving"
        elif recent_scores[-1] < recent_scores[0]:
            return "Declining"
        else:
            return "Stable"
    
    def _generate_recommendations(self, grades: List[GradeInfo], weak_assignments: List[GradeInfo]) -> List[str]:
        """Generate study recommendations based on performance"""
        recommendations = []
        
        if weak_assignments:
            recommendations.append(f"Focus on improving performance in: {', '.join([g.assignment_name for g in weak_assignments[:3]])}")
        
        # Analyze assignment types
        assignment_types = {}
        for grade in grades:
            assignment_name = grade.assignment_name.lower()
            if 'quiz' in assignment_name:
                assignment_types['quizzes'] = assignment_types.get('quizzes', 0) + 1
            elif 'exam' in assignment_name or 'test' in assignment_name:
                assignment_types['exams'] = assignment_types.get('exams', 0) + 1
            elif 'project' in assignment_name or 'assignment' in assignment_name:
                assignment_types['projects'] = assignment_types.get('projects', 0) + 1
        
        if assignment_types.get('quizzes', 0) > 0:
            recommendations.append("Consider more frequent review sessions for quiz preparation")
        
        if assignment_types.get('exams', 0) > 0:
            recommendations.append("Plan extended study sessions for upcoming exams")
        
        return recommendations
    
    def _generate_smart_study_plan(self, assignments: List[Any], grades: List[GradeInfo], 
                                 syllabus_info: List[SyllabusInfo], performance_analysis: Dict[str, Any], 
                                 days_ahead: int) -> str:
        """Generate intelligent study plan based on all available data"""
        
        # Filter upcoming assignments
        upcoming_assignments = []
        for assignment in assignments:
            if assignment.get('due_at'):
                try:
                    due_date = datetime.fromisoformat(assignment['due_at'].replace('Z', '+00:00'))
                    days_until_due = (due_date - datetime.now()).days
                    if 0 <= days_until_due <= days_ahead:
                        upcoming_assignments.append((assignment, days_until_due))
                except:
                    continue
        
        # Sort by due date and priority
        upcoming_assignments.sort(key=lambda x: (x[1], -x[0].get('points_possible', 0)))
        
        # Generate study plan
        plan = f"""# Enhanced Study Plan ({days_ahead} days ahead)

## Performance Analysis
- Overall Performance: {performance_analysis.get('overall_percentage', 'N/A')}%
- Performance Trend: {performance_analysis.get('recent_trend', 'N/A')}
- Total Completed Assignments: {performance_analysis.get('total_assignments', 0)}

## Recommendations
{chr(10).join(f"- {rec}" for rec in performance_analysis.get('recommendations', []))}

## Upcoming Assignments & Study Schedule

"""
        
        # Create daily study plan
        current_date = datetime.now().date()
        for i in range(days_ahead):
            study_date = current_date + timedelta(days=i)
            day_name = study_date.strftime('%A')
            
            plan += f"### {day_name}, {study_date.strftime('%B %d, %Y')}\n\n"
            
            # Find assignments due on this day
            day_assignments = [a for a, days in upcoming_assignments if days == i]
            
            if day_assignments:
                for assignment, _ in day_assignments:
                    plan += f"**{assignment['name']}** (Due Today - {assignment.get('points_possible', 0)} points)\n"
                    plan += f"- Review assignment requirements\n"
                    plan += f"- Complete final submission\n"
                    plan += f"- Submit before deadline\n\n"
            
            # Add study sessions for upcoming assignments
            upcoming_for_study = [a for a, days in upcoming_assignments if 1 <= days <= 3]
            if upcoming_for_study:
                plan += f"**Study Session (2-3 hours)**\n"
                for assignment, days in upcoming_for_study[:2]:  # Limit to 2 assignments per day
                    plan += f"- Work on {assignment['name']} (due in {days} days)\n"
                plan += f"- Review course materials\n"
                plan += f"- Practice problems/exercises\n\n"
            
            if not day_assignments and not upcoming_for_study:
                plan += f"**Light Review Session (1 hour)**\n"
                plan += f"- Review previous assignments\n"
                plan += f"- Organize notes\n"
                plan += f"- Plan for upcoming week\n\n"
        
        # Add syllabus insights
        if syllabus_info:
            plan += "## Syllabus Insights\n\n"
            for syllabus in syllabus_info:
                if syllabus.important_dates:
                    plan += f"**Important Dates:**\n"
                    for date in syllabus.important_dates[:5]:
                        plan += f"- {date}\n"
                    plan += "\n"
        
        return plan
