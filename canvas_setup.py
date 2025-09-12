import requests
import os
from dotenv import load_dotenv

load_dotenv()

class CanvasAPI:
    def __init__(self, base_url, access_token):
        if not base_url:
            raise ValueError("Missing CANVAS_BASE_URL")
        if not access_token:
            raise ValueError("Missing CANVAS_ACCESS_TOKEN")
        self.base_url = base_url.rstrip('/')
        self.access_token = access_token
        self.headers = {
            'Authorization': f'Bearer {access_token}',
            'Content-Type': 'application/json'
        }
    
    def get(self, endpoint, params=None):
        """Make GET request to Canvas API"""
        url = f"{self.base_url}/api/v1/{endpoint.lstrip('/')}"
        try:
            response = requests.get(url, headers=self.headers, params=params)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"{e}")
            return None
    
    def post(self, endpoint, data=None):
        """Make POST request to Canvas API"""
        url = f"{self.base_url}/api/v1/{endpoint.lstrip('/')}"
        try:
            response = requests.post(url, headers=self.headers, json=data)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"{e}")
            return None

# Initialize Canvas client
canvas_client = CanvasAPI(
    base_url=os.getenv("CANVAS_BASE_URL"), 
    access_token=os.getenv("CANVAS_ACCESS_TOKEN")
)

# Test connection
def test_canvas_connection():
    try:
        user_info = canvas_client.get("users/self")
        if user_info:
            print("Canvas connection successful!")
            print(f"Logged in as: {user_info.get('name', 'Unknown')}")
        else:
            print("Canvas connection failed")
    except Exception as e:
        print(f"{e}")

# Run test
test_canvas_connection()