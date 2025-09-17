#!/usr/bin/env python3
"""
Setup script for Canvas Automation Flow
Helps with initial configuration and dependency installation
"""

import os
import sys
import subprocess
import shutil
from pathlib import Path


def run_command(command, description):
    """Run a command and handle errors"""
    print(f"🔄 {description}...")
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
        print(f"✅ {description} completed")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ {description} failed: {e.stderr}")
        return False


def check_python_version():
    """Check if Python version is compatible"""
    version = sys.version_info
    if version.major < 3 or (version.major == 3 and version.minor < 8):
        print("❌ Python 3.8+ is required")
        return False
    print(f"✅ Python {version.major}.{version.minor}.{version.micro} detected")
    return True


def create_virtual_environment():
    """Create virtual environment"""
    if os.path.exists('.venv'):
        print("✅ Virtual environment already exists")
        return True
    
    return run_command('python -m venv .venv', 'Creating virtual environment')


def install_dependencies():
    """Install Python dependencies"""
    pip_cmd = '.venv/bin/pip' if os.name != 'nt' else '.venv\\Scripts\\pip'
    return run_command(f'{pip_cmd} install -r requirements.txt', 'Installing dependencies')


def create_env_file():
    """Create .env file from template"""
    if os.path.exists('.env'):
        print("✅ .env file already exists")
        return True
    
    env_template = """# Canvas Configuration
CANVAS_BASE_URL=https://your-school.instructure.com
CANVAS_CLIENT_ID=your_canvas_client_id
CANVAS_CLIENT_SECRET=your_canvas_client_secret
CANVAS_REDIRECT_URI=http://localhost:8000/auth/callback
CANVAS_ACCESS_TOKEN=your_canvas_access_token

# Groq AI Configuration
GROQ_API_KEY=your_groq_api_key

# Security
SECRET_KEY=your_secret_key_for_flask
ENCRYPTION_KEY=your_encryption_key_for_tokens

# Sync Configuration
SYNC_INTERVAL_MINUTES=15
SYNC_BATCH_SIZE=50
MAX_CONCURRENT_SYNCS=5
CACHE_TTL_MINUTES=30

# Notification Providers (Optional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password

FCM_SERVER_KEY=your_firebase_server_key

TWILIO_ACCOUNT_SID=your_twilio_sid
TWILIO_AUTH_TOKEN=your_twilio_token
TWILIO_FROM_NUMBER=your_twilio_number

# Logging
LOG_LEVEL=INFO
"""
    
    try:
        with open('.env', 'w') as f:
            f.write(env_template)
        print("✅ Created .env file template")
        print("📝 Please edit .env file with your actual configuration")
        return True
    except Exception as e:
        print(f"❌ Failed to create .env file: {e}")
        return False


def create_gitignore():
    """Create .gitignore file"""
    if os.path.exists('.gitignore'):
        print("✅ .gitignore already exists")
        return True
    
    gitignore_content = """# Environment variables
.env
.env.local
.env.production

# Virtual environment
.venv/
venv/
env/

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Database
*.db
*.sqlite3

# Cache
.cache/
.pytest_cache/

# Coverage
htmlcov/
.coverage
.coverage.*
coverage.xml
"""
    
    try:
        with open('.gitignore', 'w') as f:
            f.write(gitignore_content)
        print("✅ Created .gitignore file")
        return True
    except Exception as e:
        print(f"❌ Failed to create .gitignore: {e}")
        return False


def run_tests():
    """Run test suite"""
    python_cmd = '.venv/bin/python' if os.name != 'nt' else '.venv\\Scripts\\python'
    return run_command(f'{python_cmd} src/main.py test-suite', 'Running test suite')


def main():
    """Main setup function"""
    print("🚀 Canvas Automation Flow Setup")
    print("=" * 40)
    
    # Check Python version
    if not check_python_version():
        sys.exit(1)
    
    # Create virtual environment
    if not create_virtual_environment():
        sys.exit(1)
    
    # Install dependencies
    if not install_dependencies():
        sys.exit(1)
    
    # Create configuration files
    create_env_file()
    create_gitignore()
    
    # Run tests
    print("\n🧪 Running test suite...")
    if run_tests():
        print("\n🎉 Setup completed successfully!")
        print("\n📋 Next steps:")
        print("1. Edit .env file with your Canvas and Groq API credentials")
        print("2. Test connection: python src/main.py test")
        print("3. Start API server: python src/main.py api")
        print("4. Read README.md for detailed usage instructions")
    else:
        print("\n⚠️  Setup completed with test failures")
        print("Check the test output above for details")


if __name__ == '__main__':
    main()
