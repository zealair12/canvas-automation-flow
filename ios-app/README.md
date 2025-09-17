# Canvas Automation Flow - iOS App

A SwiftUI iOS app that integrates with the Canvas Automation Flow API to provide students with AI-powered assignment management, reminders, and feedback.

## 🚀 Features

- **Canvas OAuth2 Authentication**: Secure sign-in with Canvas LMS
- **Dashboard**: Overview of courses, assignments, and upcoming deadlines
- **Course Management**: View all enrolled courses with status indicators
- **Assignment Tracking**: Filter assignments by status (all, due soon, overdue)
- **Smart Reminders**: Create custom reminders for assignments
- **Settings**: Manage notifications and user preferences

## 📱 App Structure

```
CanvasAutomationFlow/
├── CanvasAutomationFlowApp.swift    # Main app entry point
├── ContentView.swift                # Tab navigation container
├── APIService.swift                 # API client and data models
├── DashboardView.swift              # Main dashboard with stats
├── AuthenticationView.swift        # Canvas OAuth2 web view
├── CoursesView.swift               # Course listing and management
├── AssignmentsView.swift           # Assignment tracking with filters
├── RemindersView.swift             # Reminder management
├── SettingsView.swift              # User settings and preferences
└── Info.plist                      # App configuration
```

## 🔧 Setup Instructions

### Prerequisites

- Xcode 15.0+
- iOS 17.0+
- Canvas Automation Flow API server running on `localhost:5000`

### Installation

1. **Open in Xcode:**
   ```bash
   cd ios-app
   open CanvasAutomationFlow.xcodeproj
   ```

2. **Configure API Endpoint:**
   - Update `baseURL` in `APIService.swift` if your API server is not on localhost
   - For production, change to your deployed API URL

3. **Build and Run:**
   - Select your target device/simulator
   - Press Cmd+R to build and run

### API Server Setup

Make sure your Canvas Automation Flow API server is running:

```bash
# In the main project directory
CANVAS_BASE_URL=https://your-school.instructure.com python src/main.py api
```

## 📋 Usage

### Authentication

1. **Launch the app** - You'll see the sign-in screen
2. **Tap "Sign In with Canvas"** - Opens Canvas OAuth2 flow
3. **Complete authentication** - Redirects back to app with token
4. **Access dashboard** - View your courses and assignments

### Dashboard

- **Quick Stats**: See course count, assignments, due soon, and overdue
- **Upcoming Assignments**: List of assignments due within 24 hours
- **Recent Reminders**: Your latest reminder notifications
- **Pull to Refresh**: Swipe down to reload data

### Courses

- **View all courses** you're enrolled in
- **Course status** indicators (available, unpublished, etc.)
- **Course descriptions** and details
- **Refresh** to sync latest data

### Assignments

- **Filter assignments** by status:
  - All assignments
  - Due soon (within 24 hours)
  - Overdue assignments
  - Completed assignments
- **Swipe to create reminders** for any assignment
- **Assignment details** including due dates and points

### Reminders

- **View all reminders** you've created
- **Create new reminders** for specific assignments
- **Set reminder timing** (hours before due date)
- **Status tracking** (pending, sent, failed)

### Settings

- **User profile** information
- **Notification preferences** (push, email, SMS)
- **App information** and version
- **Sign out** functionality

## 🔌 API Integration

The app communicates with the Canvas Automation Flow API through:

### Authentication Endpoints
- `GET /auth/login` - Get OAuth2 authorization URL
- `POST /auth/callback` - Exchange code for access token

### Data Endpoints
- `GET /api/user/profile` - Get user information
- `GET /api/user/courses` - Get user's courses
- `GET /api/courses/{id}/assignments` - Get course assignments
- `GET /api/reminders/upcoming` - Get upcoming reminders
- `POST /api/reminders` - Create new reminder

### Error Handling

The app handles various error scenarios:
- **Network errors** - Shows user-friendly messages
- **Authentication failures** - Prompts re-authentication
- **API errors** - Displays specific error messages
- **Empty states** - Shows helpful empty state screens

## 🎨 Design Features

- **SwiftUI** - Modern, declarative UI framework
- **Tab Navigation** - Easy access to all features
- **Pull to Refresh** - Intuitive data reloading
- **Swipe Actions** - Quick reminder creation
- **Status Badges** - Visual status indicators
- **Empty States** - Helpful guidance when no data
- **Loading States** - Smooth user experience

## 🔒 Security

- **OAuth2 Authentication** - Secure Canvas integration
- **Token Management** - Secure storage and refresh
- **HTTPS Only** - Encrypted API communication
- **No Sensitive Data Storage** - Tokens stored securely

## 🚀 Production Deployment

### App Store Preparation

1. **Update Bundle Identifier** in Info.plist
2. **Configure App Transport Security** for production API
3. **Add App Icons** and launch screen
4. **Test on physical devices**
5. **Submit for App Store review**

### API Configuration

```swift
// Update in APIService.swift
private let baseURL = "https://your-api-domain.com"
```

### Environment Variables

For different environments (dev, staging, production):

```swift
#if DEBUG
private let baseURL = "http://localhost:5000"
#else
private let baseURL = "https://api.canvasautomation.com"
#endif
```

## 🧪 Testing

### Manual Testing Checklist

- [ ] Authentication flow works correctly
- [ ] Dashboard loads user data
- [ ] Courses display properly
- [ ] Assignment filtering works
- [ ] Reminder creation functions
- [ ] Settings save preferences
- [ ] Error handling works
- [ ] Offline behavior is graceful

### Unit Testing

Add unit tests for:
- API service methods
- Data model parsing
- Date formatting utilities
- Error handling logic

## 📈 Future Enhancements

- **Push Notifications** - Real-time assignment reminders
- **Offline Support** - Cache data for offline viewing
- **Widget Support** - Home screen widgets for quick access
- **Apple Watch App** - Quick assignment checking
- **Siri Integration** - Voice commands for reminders
- **Dark Mode** - Enhanced visual experience
- **Accessibility** - VoiceOver and accessibility features

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
