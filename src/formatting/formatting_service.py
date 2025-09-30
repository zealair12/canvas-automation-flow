"""
Comprehensive Formatting Service
Supports tables, formulas, and structured output across all AI interfaces
"""

import re
import json
from typing import Any, Dict, List, Optional, Union
from dataclasses import dataclass
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


@dataclass
class FormattingOptions:
    """Options for formatting output"""
    include_tables: bool = True
    include_math: bool = True
    include_sources: bool = True
    table_style: str = "markdown"  # markdown, html, ascii
    math_engine: str = "latex"  # latex, katex
    color_output: bool = False
    max_table_rows: int = 50
    max_content_length: int = 10000


class FormattingService:
    """Comprehensive formatting service for AI outputs"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
    
    def format_ai_response(self, content: str, sources: List[Dict] = None, 
                          options: FormattingOptions = None) -> str:
        """Format AI response with tables, math, and structured content"""
        if options is None:
            options = FormattingOptions()
        
        formatted_content = content
        
        # Format tables
        if options.include_tables:
            formatted_content = self._format_tables(formatted_content, options)
        
        # Format math expressions
        if options.include_math:
            formatted_content = self._format_math(formatted_content, options)
        
        # Format sources
        if options.include_sources and sources:
            formatted_content = self._format_sources(formatted_content, sources)
        
        # Format structured content
        formatted_content = self._format_structured_content(formatted_content)
        
        return formatted_content
    
    def _format_tables(self, content: str, options: FormattingOptions) -> str:
        """Format tables in content"""
        # Look for table patterns and convert to proper Markdown
        table_patterns = [
            # Pattern 1: Simple data tables
            r'(\w+):\s*(\d+)\s*points?',
            # Pattern 2: List of items with scores
            r'(\w+)\s*-\s*(\d+)',
            # Pattern 3: Assignment lists
            r'(\w+.*?)\s*\((\d+)\s*points?\)',
        ]
        
        for pattern in table_patterns:
            matches = re.findall(pattern, content, re.IGNORECASE)
            if len(matches) > 2:  # Only format if we have enough data
                table_md = self._create_markdown_table(matches, options)
                # Replace the original text with formatted table
                content = re.sub(pattern, table_md, content, flags=re.IGNORECASE)
        
        return content
    
    def _create_markdown_table(self, data: List[tuple], options: FormattingOptions) -> str:
        """Create Markdown table from data"""
        if not data:
            return ""
        
        # Determine table headers based on data
        if len(data[0]) == 2:
            headers = ["Item", "Value"]
        else:
            headers = [f"Column {i+1}" for i in range(len(data[0]))]
        
        # Create table
        table_lines = []
        table_lines.append("| " + " | ".join(headers) + " |")
        table_lines.append("| " + " | ".join(["---"] * len(headers)) + " |")
        
        for row in data[:options.max_table_rows]:
            table_lines.append("| " + " | ".join(str(cell) for cell in row) + " |")
        
        if len(data) > options.max_table_rows:
            table_lines.append(f"| ... and {len(data) - options.max_table_rows} more rows |")
        
        return "\n".join(table_lines)
    
    def _format_math(self, content: str, options: FormattingOptions) -> str:
        """Format mathematical expressions"""
        # Look for common math patterns
        math_patterns = [
            # Fractions
            r'(\d+)/(\d+)',
            # Percentages
            r'(\d+(?:\.\d+)?)%',
            # Equations
            r'(\w+)\s*=\s*([^,\n]+)',
            # Ranges
            r'(\d+)\s*-\s*(\d+)',
        ]
        
        for pattern in math_patterns:
            content = re.sub(pattern, self._format_math_expression, content)
        
        return content
    
    def _format_math_expression(self, match) -> str:
        """Format individual math expression"""
        if '/' in match.group():
            # Fraction
            num, den = match.group().split('/')
            return f"$\\frac{{{num}}}{{{den}}}$"
        elif '%' in match.group():
            # Percentage
            return f"${match.group()}$"
        elif '=' in match.group():
            # Equation
            return f"${match.group()}$"
        else:
            return match.group()
    
    def _format_sources(self, content: str, sources: List[Dict]) -> str:
        """Format source citations"""
        if not sources:
            return content
        
        # Add sources section
        sources_section = "\n\n## Sources\n\n"
        
        for i, source in enumerate(sources, 1):
            # Handle both dict and string sources
            if isinstance(source, dict):
                title = source.get('title', f'Source {i}')
                url = source.get('url', '')
                
                if url:
                    sources_section += f"{i}. [{title}]({url})\n"
                else:
                    sources_section += f"{i}. {title}\n"
            elif isinstance(source, str):
                # If source is a string (URL or text), display it directly
                if source.startswith('http'):
                    sources_section += f"{i}. [{source}]({source})\n"
                else:
                    sources_section += f"{i}. {source}\n"
            else:
                # Fallback for unknown types
                sources_section += f"{i}. {str(source)}\n"
        
        return content + sources_section
    
    def _format_structured_content(self, content: str) -> str:
        """Format structured content with proper Markdown"""
        # Convert bullet points to proper Markdown
        content = re.sub(r'^[-*]\s+', '- ', content, flags=re.MULTILINE)
        
        # Convert numbered lists
        content = re.sub(r'^(\d+)\.\s+', r'\1. ', content, flags=re.MULTILINE)
        
        # Format headers
        content = re.sub(r'^(\w+.*?):$', r'## \1', content, flags=re.MULTILINE)
        
        # Format code blocks
        content = re.sub(r'`([^`]+)`', r'`\1`', content)
        
        # Format bold text
        content = re.sub(r'\*\*([^*]+)\*\*', r'**\1**', content)
        
        # Format italic text
        content = re.sub(r'\*([^*]+)\*', r'*\1*', content)
        
        return content
    
    def create_assignment_table(self, assignments: List[Dict]) -> str:
        """Create formatted table for assignments"""
        if not assignments:
            return "No assignments found."
        
        headers = ["Assignment", "Due Date", "Points", "Status"]
        table_lines = []
        table_lines.append("| " + " | ".join(headers) + " |")
        table_lines.append("| " + " | ".join(["---"] * len(headers)) + " |")
        
        for assignment in assignments:
            name = assignment.get('name', 'Unknown')
            due_date = assignment.get('due_at', 'No due date')
            points = assignment.get('points_possible', 0)
            status = assignment.get('workflow_state', 'Unknown')
            
            # Format due date
            if due_date and due_date != 'No due date':
                try:
                    dt = datetime.fromisoformat(due_date.replace('Z', '+00:00'))
                    due_date = dt.strftime('%Y-%m-%d')
                except:
                    pass
            
            table_lines.append(f"| {name} | {due_date} | {points} | {status} |")
        
        return "\n".join(table_lines)
    
    def create_grade_table(self, grades: List[Dict]) -> str:
        """Create formatted table for grades"""
        if not grades:
            return "No grades available."
        
        headers = ["Assignment", "Score", "Points Possible", "Percentage", "Grade"]
        table_lines = []
        table_lines.append("| " + " | ".join(headers) + " |")
        table_lines.append("| " + " | ".join(["---"] * len(headers)) + " |")
        
        for grade in grades:
            name = grade.get('assignment_name', 'Unknown')
            score = grade.get('score', 0)
            points_possible = grade.get('points_possible', 0)
            grade_letter = grade.get('grade', 'N/A')
            
            # Calculate percentage
            if points_possible > 0:
                percentage = f"{(score / points_possible * 100):.1f}%"
            else:
                percentage = "N/A"
            
            table_lines.append(f"| {name} | {score} | {points_possible} | {percentage} | {grade_letter} |")
        
        return "\n".join(table_lines)
    
    def create_study_schedule_table(self, schedule: List[Dict]) -> str:
        """Create formatted table for study schedule"""
        if not schedule:
            return "No study schedule available."
        
        headers = ["Date", "Time", "Activity", "Duration", "Priority"]
        table_lines = []
        table_lines.append("| " + " | ".join(headers) + " |")
        table_lines.append("| " + " | ".join(["---"] * len(headers)) + " |")
        
        for item in schedule:
            date = item.get('date', 'Unknown')
            time = item.get('time', 'TBD')
            activity = item.get('activity', 'Study session')
            duration = item.get('duration', '2 hours')
            priority = item.get('priority', 'Medium')
            
            table_lines.append(f"| {date} | {time} | {activity} | {duration} | {priority} |")
        
        return "\n".join(table_lines)
    
    def format_performance_analysis(self, analysis: Dict) -> str:
        """Format performance analysis with tables and charts"""
        if not analysis:
            return "No performance data available."
        
        formatted = "## Performance Analysis\n\n"
        
        # Overall metrics
        overall_percentage = analysis.get('overall_percentage', 0)
        total_assignments = analysis.get('total_assignments', 0)
        trend = analysis.get('recent_trend', 'Unknown')
        
        formatted += f"**Overall Performance:** {overall_percentage}%\n"
        formatted += f"**Total Assignments:** {total_assignments}\n"
        formatted += f"**Performance Trend:** {trend}\n\n"
        
        # Weak areas
        weak_areas = analysis.get('weak_areas', [])
        if weak_areas:
            formatted += "### Areas for Improvement\n\n"
            for area in weak_areas:
                formatted += f"- {area}\n"
            formatted += "\n"
        
        # Recommendations
        recommendations = analysis.get('recommendations', [])
        if recommendations:
            formatted += "### Recommendations\n\n"
            for rec in recommendations:
                formatted += f"- {rec}\n"
            formatted += "\n"
        
        return formatted
    
    def format_calendar_events(self, events: List[Dict]) -> str:
        """Format calendar events as a table"""
        if not events:
            return "No calendar events scheduled."
        
        headers = ["Event", "Start Time", "End Time", "Type", "Description"]
        table_lines = []
        table_lines.append("| " + " | ".join(headers) + " |")
        table_lines.append("| " + " | ".join(["---"] * len(headers)) + " |")
        
        for event in events:
            title = event.get('title', 'Unknown Event')
            start_time = event.get('start_time', 'TBD')
            end_time = event.get('end_time', 'TBD')
            event_type = event.get('event_type', 'study')
            description = event.get('description', '')
            
            # Format times
            try:
                if start_time != 'TBD':
                    start_dt = datetime.fromisoformat(start_time)
                    start_time = start_dt.strftime('%Y-%m-%d %H:%M')
                if end_time != 'TBD':
                    end_dt = datetime.fromisoformat(end_time)
                    end_time = end_dt.strftime('%Y-%m-%d %H:%M')
            except:
                pass
            
            table_lines.append(f"| {title} | {start_time} | {end_time} | {event_type} | {description} |")
        
        return "\n".join(table_lines)
    
    def format_syllabus_insights(self, insights: List[Dict]) -> str:
        """Format syllabus insights"""
        if not insights:
            return "No syllabus information available."
        
        formatted = "## Syllabus Insights\n\n"
        
        for insight in insights:
            course_id = insight.get('course_id', 'Unknown Course')
            grading_policy = insight.get('grading_policy', '')
            important_dates = insight.get('important_dates', [])
            
            formatted += f"### Course {course_id}\n\n"
            
            if grading_policy:
                formatted += "**Grading Policy:**\n"
                formatted += f"{grading_policy}\n\n"
            
            if important_dates:
                formatted += "**Important Dates:**\n"
                for date in important_dates:
                    formatted += f"- {date}\n"
                formatted += "\n"
        
        return formatted


# Global formatting service instance
formatting_service = FormattingService()
