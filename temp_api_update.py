# Updated import line
from models.data_models import Course, Assignment, Submission, Reminder, FeedbackDraft, AssignmentStatus, File

# File endpoints to add before notification endpoints
@app.route('/api/courses/<course_id>/files', methods=['GET'])
@require_auth
def get_course_files(course_id: str):
    """Get files for a course"""
    try:
        # Create Canvas client with the token from g.canvas_token
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        folder_id = request.args.get('folder_id')
        files_data = client.get_files(course_id, folder_id)
        
        files = []
        for file_data in files_data:
            file_obj = File(
                id=f"file_{file_data['id']}",
                canvas_file_id=str(file_data['id']),
                course_id=course_id,
                folder_id=str(file_data.get('folder_id', '')),
                display_name=file_data.get('display_name', ''),
                filename=file_data.get('filename', ''),
                content_type=file_data.get('content-type', ''),
                size=file_data.get('size', 0),
                url=file_data.get('url', ''),
                download_url=file_data.get('url', ''),  # Same as url for Canvas
                thumbnail_url=file_data.get('thumbnail_url'),
                mime_class=file_data.get('mime_class', ''),
                locked=file_data.get('locked', False),
                hidden=file_data.get('hidden', False),
                uuid=file_data.get('uuid', '')
            )
            
            files.append(file_obj.to_dict())
        
        return jsonify({'files': files})
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/courses/<course_id>/files/<file_id>', methods=['GET'])
@require_auth
def get_file_details(course_id: str, file_id: str):
    """Get detailed file information"""
    try:
        # Create Canvas client with the token from g.canvas_token
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        file_data = client.get_file(course_id, file_id)
        
        file_obj = File(
            id=f"file_{file_data['id']}",
            canvas_file_id=str(file_data['id']),
            course_id=course_id,
            folder_id=str(file_data.get('folder_id', '')),
            display_name=file_data.get('display_name', ''),
            filename=file_data.get('filename', ''),
            content_type=file_data.get('content-type', ''),
            size=file_data.get('size', 0),
            url=file_data.get('url', ''),
            download_url=file_data.get('url', ''),
            thumbnail_url=file_data.get('thumbnail_url'),
            mime_class=file_data.get('mime_class', ''),
            locked=file_data.get('locked', False),
            hidden=file_data.get('hidden', False),
            uuid=file_data.get('uuid', '')
        )
        
        return jsonify({'file': file_obj.to_dict()})
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/courses/<course_id>/folders', methods=['GET'])
@require_auth
def get_course_folders(course_id: str):
    """Get folders for a course"""
    try:
        # Create Canvas client with the token from g.canvas_token
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        folders_data = client.get_folders(course_id)
        
        folders = []
        for folder_data in folders_data:
            folders.append({
                'id': f"folder_{folder_data['id']}",
                'canvas_folder_id': str(folder_data['id']),
                'name': folder_data.get('name', ''),
                'full_name': folder_data.get('full_name', ''),
                'parent_folder_id': folder_data.get('parent_folder_id'),
                'files_count': folder_data.get('files_count', 0),
                'folders_count': folder_data.get('folders_count', 0),
                'locked': folder_data.get('locked', False),
                'hidden': folder_data.get('hidden', False)
            })
        
        return jsonify({'folders': folders})
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/api/user/submissions', methods=['GET'])
@require_auth
def get_user_submissions():
    """Get submissions for current user across all courses"""
    try:
        # Create Canvas client with the token from g.canvas_token
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        # Get user's courses first
        courses_data = client.get_courses()
        all_submissions = []
        
        for course_data in courses_data:
            course_id = str(course_data['id'])
            try:
                submissions_data = client.get_user_submissions(course_id, 'self')
                
                for submission_data in submissions_data:
                    submission = Submission(
                        id=f"sub_{submission_data['id']}",
                        canvas_submission_id=str(submission_data['id']),
                        assignment_id=str(submission_data['assignment_id']),
                        user_id=str(submission_data['user_id']),
                        score=submission_data.get('score'),
                        grade=submission_data.get('grade'),
                        workflow_state=submission_data.get('workflow_state', 'unsubmitted'),
                        late=submission_data.get('late', False),
                        excused=submission_data.get('excused', False),
                        attempt=submission_data.get('attempt', 0),
                        body=submission_data.get('body'),
                        url=submission_data.get('url'),
                        attachments=submission_data.get('attachments', [])
                    )
                    
                    if submission_data.get('submitted_at'):
                        submission.submitted_at = datetime.fromisoformat(submission_data['submitted_at'].replace('Z', '+00:00'))
                    
                    all_submissions.append(submission.to_dict())
                    
            except CanvasAPIError:
                # Skip courses where we can't access submissions
                continue
        
        return jsonify({'submissions': all_submissions})
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500


# File download proxy endpoint
@app.route('/api/files/<file_id>/download', methods=['GET'])
@require_auth
def download_file(file_id: str):
    """Proxy file download through backend (with authentication)"""
    try:
        # Create Canvas client with the token from g.canvas_token
        client = CanvasAPIClient(
            base_url=os.getenv('CANVAS_BASE_URL'),
            access_token=g.canvas_token
        )
        
        # Get file details to get the download URL
        course_id = request.args.get('course_id')
        if not course_id:
            return jsonify({'error': 'Missing course_id parameter'}), 400
            
        file_data = client.get_file(course_id, file_id)
        download_url = file_data.get('url')
        
        if not download_url:
            return jsonify({'error': 'File download URL not available'}), 404
        
        # Proxy the download request with authentication
        response = client.session.get(download_url, stream=True)
        response.raise_for_status()
        
        # Return file with proper headers
        from flask import Response
        return Response(
            response.iter_content(chunk_size=8192),
            content_type=file_data.get('content-type', 'application/octet-stream'),
            headers={
                'Content-Disposition': f'attachment; filename="{file_data.get("display_name", "file")}"',
                'Content-Length': str(file_data.get('size', 0))
            }
        )
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500
