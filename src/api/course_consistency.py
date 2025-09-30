"""
Course Consistency Checker
Compares Canvas API courses with app-visible courses and provides recommendations
"""

import logging
from typing import List, Dict, Any, Tuple
from datetime import datetime
from dataclasses import dataclass

logger = logging.getLogger(__name__)

@dataclass
class CourseConsistencyReport:
    """Report of course consistency analysis"""
    total_api_courses: int
    total_app_courses: int
    missing_from_app: List[Dict[str, Any]]
    restricted_courses: List[Dict[str, Any]]
    future_courses: List[Dict[str, Any]]
    past_courses: List[Dict[str, Any]]
    recommendations: List[str]

class CourseConsistencyChecker:
    """Analyzes course consistency between Canvas API and app display"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
    
    def analyze_course_consistency(self, api_courses: List[Dict[str, Any]], 
                                 app_courses: List[Dict[str, Any]]) -> CourseConsistencyReport:
        """
        Analyze consistency between API courses and app-visible courses
        
        Args:
            api_courses: Full list of courses from Canvas API
            app_courses: Courses visible in the app (may be filtered)
            
        Returns:
            CourseConsistencyReport with analysis and recommendations
        """
        self.logger.info(f"Analyzing {len(api_courses)} API courses vs {len(app_courses)} app courses")
        
        # Create sets for comparison
        api_course_ids = {course.get('id') for course in api_courses}
        app_course_ids = {course.get('id') for course in app_courses}
        
        # Find missing courses
        missing_from_app = [
            course for course in api_courses 
            if course.get('id') not in app_course_ids
        ]
        
        # Categorize courses
        restricted_courses = [
            course for course in api_courses 
            if course.get('access_restricted_by_date', False)
        ]
        
        future_courses = self._get_future_courses(api_courses)
        past_courses = self._get_past_courses(api_courses)
        
        # Generate recommendations
        recommendations = self._generate_recommendations(
            missing_from_app, restricted_courses, future_courses, past_courses
        )
        
        return CourseConsistencyReport(
            total_api_courses=len(api_courses),
            total_app_courses=len(app_courses),
            missing_from_app=missing_from_app,
            restricted_courses=restricted_courses,
            future_courses=future_courses,
            past_courses=past_courses,
            recommendations=recommendations
        )
    
    def _get_future_courses(self, courses: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Get courses that haven't started yet"""
        now = datetime.utcnow()
        future_courses = []
        
        for course in courses:
            start_at = course.get('start_at')
            if start_at:
                try:
                    start_date = datetime.fromisoformat(start_at.replace('Z', '+00:00'))
                    if start_date > now:
                        future_courses.append(course)
                except (ValueError, AttributeError):
                    continue
        
        return future_courses
    
    def _get_past_courses(self, courses: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Get courses that have ended"""
        now = datetime.utcnow()
        past_courses = []
        
        for course in courses:
            end_at = course.get('end_at')
            if end_at:
                try:
                    end_date = datetime.fromisoformat(end_at.replace('Z', '+00:00'))
                    if end_date < now:
                        past_courses.append(course)
                except (ValueError, AttributeError):
                    continue
        
        return past_courses
    
    def _generate_recommendations(self, missing_courses: List[Dict[str, Any]], 
                                restricted_courses: List[Dict[str, Any]],
                                future_courses: List[Dict[str, Any]],
                                past_courses: List[Dict[str, Any]]) -> List[str]:
        """Generate actionable recommendations"""
        recommendations = []
        
        if missing_courses:
            recommendations.append(
                f"⚠️ {len(missing_courses)} courses are missing from app view. "
                "Check if they're starred in Canvas dashboard."
            )
        
        if restricted_courses:
            recommendations.append(
                f"🔒 {len(restricted_courses)} courses are access-restricted by date. "
                "They may become available when the term starts."
            )
        
        if future_courses:
            recommendations.append(
                f"📅 {len(future_courses)} future courses found. "
                "Consider starring them in Canvas for easy access."
            )
        
        if past_courses:
            recommendations.append(
                f"📚 {len(past_courses)} past courses found. "
                "These may be hidden by default in the app."
            )
        
        if not recommendations:
            recommendations.append("✅ All courses are properly synchronized between API and app.")
        
        return recommendations
    
    def format_report_table(self, report: CourseConsistencyReport) -> str:
        """Format the report as a human-readable table"""
        table = []
        table.append("=" * 80)
        table.append("COURSE CONSISTENCY REPORT")
        table.append("=" * 80)
        table.append(f"API Courses: {report.total_api_courses}")
        table.append(f"App Courses: {report.total_app_courses}")
        table.append("")
        
        if report.missing_from_app:
            table.append("MISSING FROM APP:")
            table.append("-" * 40)
            for course in report.missing_from_app:
                name = course.get('name', 'Unknown')
                course_id = course.get('id', 'Unknown')
                term = course.get('term', {}).get('name', 'Unknown Term')
                table.append(f"  • {name} (ID: {course_id}) - {term}")
            table.append("")
        
        if report.restricted_courses:
            table.append("ACCESS RESTRICTED:")
            table.append("-" * 40)
            for course in report.restricted_courses:
                name = course.get('name', 'Unknown')
                course_id = course.get('id', 'Unknown')
                table.append(f"  • {name} (ID: {course_id})")
            table.append("")
        
        if report.future_courses:
            table.append("FUTURE COURSES:")
            table.append("-" * 40)
            for course in report.future_courses:
                name = course.get('name', 'Unknown')
                start_at = course.get('start_at', 'Unknown')
                table.append(f"  • {name} - Starts: {start_at}")
            table.append("")
        
        if report.past_courses:
            table.append("PAST COURSES:")
            table.append("-" * 40)
            for course in report.past_courses:
                name = course.get('name', 'Unknown')
                end_at = course.get('end_at', 'Unknown')
                table.append(f"  • {name} - Ended: {end_at}")
            table.append("")
        
        table.append("RECOMMENDATIONS:")
        table.append("-" * 40)
        for i, rec in enumerate(report.recommendations, 1):
            table.append(f"  {i}. {rec}")
        
        table.append("=" * 80)
        
        return "\n".join(table)

# Example usage
if __name__ == "__main__":
    # Mock data for testing
    api_courses = [
        {
            "id": "14842",
            "name": "Fall 2024 Composition I",
            "term": {"name": "Fall 2024"},
            "access_restricted_by_date": False,
            "start_at": "2024-08-12T05:00:00Z",
            "end_at": "2024-12-14T05:59:59Z"
        },
        {
            "id": "14928",
            "name": "Course 14928",
            "term": {"name": "Fall 2024"},
            "access_restricted_by_date": True,
            "start_at": "2024-08-12T05:00:00Z"
        }
    ]
    
    app_courses = [
        {
            "id": "14842",
            "name": "Fall 2024 Composition I",
            "term": {"name": "Fall 2024"}
        }
    ]
    
    checker = CourseConsistencyChecker()
    report = checker.analyze_course_consistency(api_courses, app_courses)
    print(checker.format_report_table(report))
