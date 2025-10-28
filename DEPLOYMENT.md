# Backend Deployment Guide for App Store

## 🚀 Quick Start: Deploy to Railway (Recommended)

### Step 1: Sign Up for Railway
1. Go to [Railway.app](https://railway.app)
2. Sign up with GitHub
3. Get $5/month free credit

### Step 2: Deploy Your Backend

#### Option A: GitHub Integration (Easiest)
```bash
# Push code to GitHub (already done ✓)
# Then in Railway dashboard:
# 1. Click "New Project"
# 2. Click "Deploy from GitHub repo"
# 3. Select your canvas-automation-flow repo
# 4. Railway auto-detects Python and deploys
```

#### Option B: Railway CLI
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Deploy
railway init
railway up
```

### Step 3: Set Environment Variables

In Railway dashboard, go to **Variables** tab and add:

```bash
CANVAS_BASE_URL=https://your-canvas-instance.instructure.com
CANVAS_ACCESS_TOKEN=your_canvas_api_token
GROQ_API_KEY=your_groq_api_key
PERPLEXITY_API_KEY=your_perplexity_api_key
SECRET_KEY=your_secret_key_here
ENCRYPTION_KEY=your_encryption_key_here
```

### Step 4: Get Your Backend URL

Railway will give you a URL like:
```
https://canvas-automation-flow-production.up.railway.app
```

**Copy this URL!** You'll need it for the iOS app.

---

## 🔧 Update iOS App for Production

### Update APIService.swift

Open `ios-app/CanvasAutomationFlow/CanvasAutomationFlow/APIService.swift`:

```swift
// Change from localhost to your Railway URL
private let baseURL = "https://canvas-automation-flow-production.up.railway.app"
```

---

## 📱 Alternative Hosting Options

### Option 1: Render.com

1. **Sign up:** [render.com](https://render.com)
2. **Create Web Service:**
   - Connect your GitHub repo
   - Select Python environment
   - Build command: `pip install -r requirements.txt`
   - Start command: `python3 -m src.api.app`
3. **Add environment variables** (same as Railway)
4. **Get URL:** `https://canvas-automation-flow.onrender.com`

### Option 2: Fly.io

```bash
# Install Fly CLI
curl -L https://fly.io/install.sh | sh

# Login
fly auth login

# Launch app
fly launch

# Deploy
fly deploy
```

### Option 3: DigitalOcean App Platform

1. Sign up at [digitalocean.com](https://www.digitalocean.com)
2. Create App → GitHub → Select repo
3. Add environment variables
4. Deploy

---

## ✅ Post-Deployment Checklist

### 1. Test Your Backend
```bash
# Test health endpoint
curl https://your-backend-url.com/health

# Test API
curl https://your-backend-url.com/api/courses
```

### 2. Update iOS App
- Change `baseURL` in `APIService.swift`
- Test in simulator
- Make sure HTTPS is working

### 3. Test on Device
- Build app on physical device
- Test all API calls
- Check error handling

### 4. Submit to App Store
- Archive in Xcode
- Upload to App Store Connect
- Set production backend URL

---

## 🌐 Production Backend URLs

Update these in your iOS app configuration:

### Development (Local)
```
http://localhost:5000
```

### Staging (TestFlight)
```
https://your-staging-railway.up.railway.app
```

### Production (App Store)
```
https://your-production-railway.up.railway.app
```

---

## 🔒 Security Considerations

### HTTPS Only
- All production APIs must use HTTPS
- Railway/Render provide free SSL certificates
- Never use HTTP in production

### API Rate Limiting
Consider adding rate limiting:

```python
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)
```

### CORS Configuration
Update CORS for production:

```python
CORS(app, resources={
    r"/api/*": {
        "origins": ["*"],  # Or specific iOS bundle IDs
        "methods": ["GET", "POST", "PUT", "DELETE"],
        "allow_headers": ["Content-Type", "Authorization"]
    }
})
```

---

## 📊 Monitoring

### Railway Dashboard
- View logs in real-time
- Monitor resource usage
- Check deployment history

### Error Tracking
Consider adding Sentry:
```bash
pip install sentry-sdk[flask]
```

---

## 💰 Cost Estimates

### Railway (Recommended)
- **Free Tier:** $5/month credit (usually enough)
- **Hobby Plan:** $5/month
- **Pro Plan:** $20/month

### Render
- **Free Tier:** Available (service sleeps after inactivity)
- **Starter:** $7/month
- **Professional:** $25/month

### Fly.io
- **Free Tier:** Available
- **Paid:** $5-20/month (based on usage)

### DigitalOcean
- **Starter:** $5/month
- **Professional:** $12-25/month

---

## 🚀 Quick Deploy Checklist

- [ ] Sign up for Railway/Render/Fly.io
- [ ] Push code to GitHub (done ✓)
- [ ] Connect repo to hosting platform
- [ ] Add environment variables
- [ ] Deploy backend
- [ ] Get production URL
- [ ] Update `baseURL` in iOS app
- [ ] Test backend in production
- [ ] Build iOS app for production
- [ ] Submit to App Store

---

## 🆘 Troubleshooting

### Backend Not Starting
- Check logs in hosting dashboard
- Verify environment variables
- Check Python version

### iOS App Can't Connect
- Verify backend URL is HTTPS
- Check CORS settings
- Test with curl first

### API Errors
- Check backend logs
- Verify API keys are correct
- Test endpoints manually

---

## 📞 Support

- **Railway:** [docs.railway.app](https://docs.railway.app)
- **Render:** [render.com/docs](https://render.com/docs)
- **Fly.io:** [fly.io/docs](https://fly.io/docs)
- **This App:** Open issue on GitHub

