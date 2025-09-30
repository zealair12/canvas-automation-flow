"""
Canvas File Upload Service
Implements the 3-step file upload process as per Canvas API documentation
https://developerdocs.instructure.com/services/canvas/basics/file.file_uploads
"""

import os
import requests
import logging
from typing import Dict, Any, Optional, Tuple
from datetime import datetime

logger = logging.getLogger(__name__)


class CanvasFileUploadService:
    """Service for uploading files to Canvas using the 3-step process"""
    
    def __init__(self, base_url: str, access_token: str):
        self.base_url = base_url.rstrip('/')
        self.access_token = access_token
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Bearer {access_token}',
            'User-Agent': 'CanvasAutomationFlow/1.0'
        })
    
    def upload_file_to_course(self, course_id: str, file_path: str, 
                            parent_folder_path: Optional[str] = None,
                            on_duplicate: str = 'overwrite') -> Dict[str, Any]:
        """
        Upload a file to a course using the 3-step process
        
        Args:
            course_id: Canvas course ID
            file_path: Local path to the file to upload
            parent_folder_path: Folder path within the course (optional)
            on_duplicate: How to handle duplicates ('overwrite' or 'rename')
            
        Returns:
            Dict containing file information on success
        """
        try:
            # Step 1: Notify Canvas about the file upload
            upload_info = self._step1_notify_canvas(
                course_id, file_path, parent_folder_path, on_duplicate
            )
            
            # Step 2: Upload file data to the provided URL
            upload_response = self._step2_upload_file_data(upload_info, file_path)
            
            # Step 3: Confirm upload success
            file_info = self._step3_confirm_upload(upload_response)
            
            return file_info
            
        except Exception as e:
            logger.error(f"File upload failed: {e}")
            raise
    
    def upload_file_to_user(self, file_path: str, 
                          parent_folder_path: Optional[str] = None,
                          on_duplicate: str = 'overwrite') -> Dict[str, Any]:
        """
        Upload a file to user's personal files using the 3-step process
        
        Args:
            file_path: Local path to the file to upload
            parent_folder_path: Folder path within user files (optional)
            on_duplicate: How to handle duplicates ('overwrite' or 'rename')
            
        Returns:
            Dict containing file information on success
        """
        try:
            # Step 1: Notify Canvas about the file upload
            upload_info = self._step1_notify_canvas_user(
                file_path, parent_folder_path, on_duplicate
            )
            
            # Step 2: Upload file data to the provided URL
            upload_response = self._step2_upload_file_data(upload_info, file_path)
            
            # Step 3: Confirm upload success
            file_info = self._step3_confirm_upload(upload_response)
            
            return file_info
            
        except Exception as e:
            logger.error(f"User file upload failed: {e}")
            raise
    
    def upload_file_via_url(self, course_id: str, file_url: str, 
                          file_name: str, file_size: int,
                          content_type: Optional[str] = None,
                          parent_folder_path: Optional[str] = None) -> Dict[str, Any]:
        """
        Upload a file to Canvas by providing a URL (Canvas will download it)
        
        Args:
            course_id: Canvas course ID
            file_url: Public URL to the file
            file_name: Name for the file in Canvas
            file_size: Size of the file in bytes
            content_type: MIME type of the file (optional)
            parent_folder_path: Folder path within the course (optional)
            
        Returns:
            Dict containing file information on success
        """
        try:
            # Step 1: Post file URL to Canvas
            upload_info = self._step1_post_file_url(
                course_id, file_url, file_name, file_size, content_type, parent_folder_path
            )
            
            # Check if we need to follow up with step 2 (newer behavior)
            if 'upload_url' in upload_info:
                # Step 2: POST to the upload URL (newer behavior)
                upload_response = self._step2_post_upload_url(upload_info, file_url)
                
                # Step 3: Check progress
                file_info = self._step3_check_progress(upload_info.get('progress', {}))
            else:
                # Older behavior - Canvas handles everything
                file_info = self._step3_check_progress(upload_info.get('progress', {}))
            
            return file_info
            
        except Exception as e:
            logger.error(f"URL file upload failed: {e}")
            raise
    
    def _step1_notify_canvas(self, course_id: str, file_path: str,
                           parent_folder_path: Optional[str], on_duplicate: str) -> Dict[str, Any]:
        """Step 1: Notify Canvas about the file upload and get upload token"""
        
        file_name = os.path.basename(file_path)
        file_size = os.path.getsize(file_path)
        
        # Guess content type from file extension
        content_type = self._guess_content_type(file_name)
        
        url = f"{self.base_url}/api/v1/courses/{course_id}/files"
        
        data = {
            'name': file_name,
            'size': file_size,
            'content_type': content_type,
            'on_duplicate': on_duplicate
        }
        
        if parent_folder_path:
            data['parent_folder_path'] = parent_folder_path
        
        logger.info(f"Step 1: Notifying Canvas about file upload - {file_name} ({file_size} bytes)")
        
        response = self.session.post(url, data=data)
        response.raise_for_status()
        
        upload_info = response.json()
        logger.info(f"Step 1 complete: Got upload URL and params")
        
        return upload_info
    
    def _step1_notify_canvas_user(self, file_path: str,
                                parent_folder_path: Optional[str], on_duplicate: str) -> Dict[str, Any]:
        """Step 1: Notify Canvas about user file upload and get upload token"""
        
        file_name = os.path.basename(file_path)
        file_size = os.path.getsize(file_path)
        
        # Guess content type from file extension
        content_type = self._guess_content_type(file_name)
        
        url = f"{self.base_url}/api/v1/users/self/files"
        
        data = {
            'name': file_name,
            'size': file_size,
            'content_type': content_type,
            'on_duplicate': on_duplicate
        }
        
        if parent_folder_path:
            data['parent_folder_path'] = parent_folder_path
        
        logger.info(f"Step 1: Notifying Canvas about user file upload - {file_name} ({file_size} bytes)")
        
        response = self.session.post(url, data=data)
        response.raise_for_status()
        
        upload_info = response.json()
        logger.info(f"Step 1 complete: Got upload URL and params")
        
        return upload_info
    
    def _step1_post_file_url(self, course_id: str, file_url: str, file_name: str,
                           file_size: int, content_type: Optional[str], 
                           parent_folder_path: Optional[str]) -> Dict[str, Any]:
        """Step 1: Post file URL to Canvas for URL-based upload"""
        
        if not content_type:
            content_type = self._guess_content_type(file_name)
        
        url = f"{self.base_url}/api/v1/courses/{course_id}/files"
        
        data = {
            'url': file_url,
            'name': file_name,
            'size': file_size,
            'content_type': content_type,
            'submit_assignment': True
        }
        
        if parent_folder_path:
            data['parent_folder_path'] = parent_folder_path
        
        logger.info(f"Step 1: Posting file URL to Canvas - {file_name} from {file_url}")
        
        response = self.session.post(url, data=data)
        response.raise_for_status()
        
        upload_info = response.json()
        logger.info(f"Step 1 complete: Got upload info")
        
        return upload_info
    
    def _step2_upload_file_data(self, upload_info: Dict[str, Any], file_path: str) -> requests.Response:
        """Step 2: Upload file data to the URL provided in step 1"""
        
        upload_url = upload_info['upload_url']
        upload_params = upload_info['upload_params']
        
        logger.info(f"Step 2: Uploading file data to {upload_url}")
        
        # Prepare multipart form data
        files = {'file': open(file_path, 'rb')}
        
        try:
            # Upload file data (don't include auth token for this request)
            upload_session = requests.Session()
            response = upload_session.post(upload_url, data=upload_params, files=files)
            response.raise_for_status()
            
            logger.info(f"Step 2 complete: File data uploaded successfully")
            return response
            
        finally:
            files['file'].close()
    
    def _step2_post_upload_url(self, upload_info: Dict[str, Any], file_url: str) -> requests.Response:
        """Step 2: POST to upload URL for URL-based uploads (newer behavior)"""
        
        upload_url = upload_info['upload_url']
        upload_params = upload_info['upload_params']
        
        # Add the target URL to the params
        upload_params['target_url'] = file_url
        
        logger.info(f"Step 2: POSTing to upload URL for URL-based upload")
        
        response = requests.post(upload_url, data=upload_params)
        response.raise_for_status()
        
        logger.info(f"Step 2 complete: URL upload initiated")
        return response
    
    def _step3_confirm_upload(self, upload_response: requests.Response) -> Dict[str, Any]:
        """Step 3: Confirm upload success by following redirect or making GET request"""
        
        logger.info(f"Step 3: Confirming upload success")
        
        # Check if we got a redirect
        if upload_response.status_code in [301, 302, 303, 307, 308]:
            location = upload_response.headers.get('Location')
            if location:
                logger.info(f"Following redirect to: {location}")
                # Make GET request to the redirect location
                response = self.session.get(location)
                response.raise_for_status()
                file_info = response.json()
            else:
                raise Exception("Redirect response missing Location header")
        else:
            # Direct response
            file_info = upload_response.json()
        
        logger.info(f"Step 3 complete: Upload confirmed, file ID: {file_info.get('id')}")
        return file_info
    
    def _step3_check_progress(self, progress_info: Dict[str, Any]) -> Dict[str, Any]:
        """Step 3: Check progress for URL-based uploads"""
        
        if not progress_info:
            raise Exception("No progress information available")
        
        progress_url = progress_info.get('url')
        if not progress_url:
            raise Exception("No progress URL available")
        
        logger.info(f"Step 3: Checking upload progress at {progress_url}")
        
        # Poll the progress endpoint until completion
        max_attempts = 30  # 5 minutes max
        attempt = 0
        
        while attempt < max_attempts:
            response = self.session.get(progress_url)
            response.raise_for_status()
            
            progress_data = response.json()
            workflow_state = progress_data.get('workflow_state')
            
            if workflow_state == 'completed':
                # Get the file ID from results
                results = progress_data.get('results', {})
                file_id = results.get('id')
                
                if file_id:
                    # Fetch the file details
                    file_url = f"{self.base_url}/api/v1/files/{file_id}"
                    file_response = self.session.get(file_url)
                    file_response.raise_for_status()
                    
                    file_info = file_response.json()
                    logger.info(f"Step 3 complete: URL upload completed, file ID: {file_id}")
                    return file_info
                else:
                    raise Exception("Upload completed but no file ID in results")
            
            elif workflow_state == 'failed':
                raise Exception(f"Upload failed: {progress_data.get('message', 'Unknown error')}")
            
            # Wait before next check
            import time
            time.sleep(10)
            attempt += 1
        
        raise Exception("Upload progress check timed out")
    
    def _guess_content_type(self, file_name: str) -> str:
        """Guess content type from file extension"""
        
        extension = os.path.splitext(file_name)[1].lower()
        
        content_types = {
            '.pdf': 'application/pdf',
            '.doc': 'application/msword',
            '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            '.xls': 'application/vnd.ms-excel',
            '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            '.ppt': 'application/vnd.ms-powerpoint',
            '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            '.txt': 'text/plain',
            '.rtf': 'application/rtf',
            '.html': 'text/html',
            '.htm': 'text/html',
            '.xml': 'application/xml',
            '.zip': 'application/zip',
            '.rar': 'application/x-rar-compressed',
            '.7z': 'application/x-7z-compressed',
            '.jpg': 'image/jpeg',
            '.jpeg': 'image/jpeg',
            '.png': 'image/png',
            '.gif': 'image/gif',
            '.bmp': 'image/bmp',
            '.svg': 'image/svg+xml',
            '.mp4': 'video/mp4',
            '.avi': 'video/x-msvideo',
            '.mov': 'video/quicktime',
            '.wmv': 'video/x-ms-wmv',
            '.mp3': 'audio/mpeg',
            '.wav': 'audio/wav',
            '.ogg': 'audio/ogg',
            '.flac': 'audio/flac'
        }
        
        return content_types.get(extension, 'application/octet-stream')
    
    def get_file_info(self, file_id: str) -> Dict[str, Any]:
        """Get information about an uploaded file"""
        
        url = f"{self.base_url}/api/v1/files/{file_id}"
        response = self.session.get(url)
        response.raise_for_status()
        
        return response.json()
    
    def delete_file(self, file_id: str) -> bool:
        """Delete a file from Canvas"""
        
        url = f"{self.base_url}/api/v1/files/{file_id}"
        response = self.session.delete(url)
        
        if response.status_code == 200:
            logger.info(f"File {file_id} deleted successfully")
            return True
        else:
            logger.error(f"Failed to delete file {file_id}: {response.status_code}")
            return False
