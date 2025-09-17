#!/usr/bin/env python3

# Script to add file endpoints to the API

file_endpoints = '''
# File endpoints
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
        
        # Return the download URL for client to use directly
        return jsonify({
            'download_url': download_url,
            'filename': file_data.get('display_name', 'file'),
            'content_type': file_data.get('content-type', 'application/octet-stream'),
            'size': file_data.get('size', 0)
        })
        
    except CanvasAPIError as e:
        logger.error(f"Canvas API error: {e}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({'error': 'Internal server error'}), 500


'''

# Read the current file
with open('src/api/app.py', 'r') as f:
    lines = f.readlines()

# Find the line with "# Notification endpoints"
insert_line = None
for i, line in enumerate(lines):
    if "# Notification endpoints" in line:
        insert_line = i
        break

if insert_line is not None:
    # Insert the file endpoints before the notification endpoints
    lines.insert(insert_line, file_endpoints)
    
    # Write back to file
    with open('src/api/app.py', 'w') as f:
        f.writelines(lines)
    
    print("✅ File endpoints added successfully!")
else:
    print("❌ Could not find insertion point")
