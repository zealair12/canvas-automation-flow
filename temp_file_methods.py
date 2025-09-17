    def get_files(self, course_id: str, folder_id: str = None) -> List[Dict[str, Any]]:
        """Get files for a course"""
        cache_key = f"files_{course_id}_{folder_id}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        endpoint = f'courses/{course_id}/files'
        params = {}
        if folder_id:
            params['folder_id'] = folder_id
        
        response = self._make_request('GET', endpoint, params=params)
        data = response.json()
        self._set_cache(cache_key, data)
        return data
    
    def get_file(self, course_id: str, file_id: str) -> Dict[str, Any]:
        """Get specific file details"""
        cache_key = f"file_{course_id}_{file_id}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        response = self._make_request('GET', f'courses/{course_id}/files/{file_id}')
        data = response.json()
        self._set_cache(cache_key, data)
        return data
    
    def get_folders(self, course_id: str) -> List[Dict[str, Any]]:
        """Get folders for a course"""
        cache_key = f"folders_{course_id}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        response = self._make_request('GET', f'courses/{course_id}/folders')
        data = response.json()
        self._set_cache(cache_key, data)
        return data
    
    def get_user_submissions(self, course_id: str, user_id: str = 'self') -> List[Dict[str, Any]]:
        """Get submissions for current user"""
        cache_key = f"user_submissions_{course_id}_{user_id}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached
        
        endpoint = f'courses/{course_id}/students/submissions'
        params = {'student_ids[]': ['self']} if user_id == 'self' else {'student_ids[]': [user_id]}
        
        response = self._make_request('GET', endpoint, params=params)
        data = response.json()
        self._set_cache(cache_key, data)
        return data

