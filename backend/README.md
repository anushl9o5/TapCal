# TapCal Backend API

Backend API for TapCal Android app - AI-powered calendar event extraction using Google Gemini.

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ installed
- Gemini API key ([Get one here](https://aistudio.google.com/app/apikey))

### Local Development

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Set up environment variables:**
   ```bash
   # Copy the example file
   cp .env.example .env
   
   # Edit .env and add your Gemini API key
   nano .env
   ```

3. **Run the development server:**
   ```bash
   npm run dev
   ```
   
   Server will start at `http://localhost:3000`

4. **Test the API:**
   
   **Option A: Using the HTML Test Page (Easiest)**
   ```bash
   # Open test.html in your browser
   open test.html  # macOS
   # or just double-click test.html
   ```
   
   **Option B: Using the Node.js Test Script**
   ```bash
   # Health check only
   node test-api.js
   
   # Test with an image file
   node test-api.js path/to/screenshot.png
   ```
   
   **Option C: Using curl (manual)**
   ```bash
   curl http://localhost:3000/api/health
   ```

## 📡 API Endpoints

### `GET /`
Returns API information and available endpoints.

**Response:**
```json
{
  "name": "TapCal Backend API",
  "version": "1.0.0",
  "endpoints": {
    "health": "GET /api/health",
    "analyze": "POST /api/analyze"
  }
}
```

---

### `GET /api/health`
Health check endpoint to verify the API is running.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-12-04T10:30:00.000Z",
  "service": "TapCal Backend API"
}
```

---

### `POST /api/analyze`
Analyzes a cropped screen image and extracts calendar event details.

**Request Body:**
```json
{
  "image": "base64_encoded_image_string",
  "context": "messaging"  // Optional: messaging, email, browser, upload
}
```

**Success Response (200):**
```json
{
  "success": true,
  "event": {
    "title": "Meeting with Sarah",
    "date": "2024-12-05",
    "time": "14:00",
    "location": "Conference Room",
    "description": "Discuss Q2 roadmap"
  }
}
```

**No Event Detected (200):**
```json
{
  "success": false,
  "error": "No calendar event detected in the image"
}
```

**Error Response (400/500):**
```json
{
  "success": false,
  "error": "Error message describing what went wrong"
}
```

## 🧪 Testing with Sample Images

### Method 1: HTML Test Page (Recommended - No Terminal Crashes!)

**The easiest way to test with images:**

1. Open `test.html` in your browser:
   ```bash
   open test.html  # macOS
   xdg-open test.html  # Linux
   # or just double-click the file
   ```

2. Click "Test Connection" to verify backend is running
3. Click "Select an image" and choose a screenshot
4. Click "Analyze Image" and watch the magic! ✨

**Benefits:**
- ✅ No terminal crashes from large base64 strings
- ✅ Visual preview of your image
- ✅ Beautiful formatted results
- ✅ Response time tracking

### Method 2: Node.js Test Script

**For command-line testing:**

```bash
# Test connection only
node test-api.js

# Analyze a specific image file
node test-api.js screenshots/test.png

# Test against deployed backend
node test-api.js https://your-api.vercel.app screenshots/test.png
```

### Method 3: Using Postman

1. Create a new POST request
2. URL: `http://localhost:3000/api/analyze`
3. Headers: `Content-Type: application/json`
4. Body (raw JSON):
   ```json
   {
     "image": "base64_string_here",
     "context": "messaging"
   }
   ```

**Tip:** Use Postman's file upload feature instead of raw base64 to avoid crashes.

### Method 4: Using the TypeScript WebApp

Your existing webapp can test the backend! Update `geminiService.ts`:

```typescript
// Replace the direct Gemini call with backend call
export const analyzeScreenRegion = async (base64Image: string): Promise<CalendarEvent | null> => {
  const response = await fetch('http://localhost:3000/api/analyze', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ image: base64Image.split(',')[1] || base64Image })
  });
  
  const data = await response.json();
  return data.success ? data.event : null;
};
```

## 📦 Project Structure

```
backend/
├── src/
│   ├── index.ts              # Express server setup
│   ├── routes/
│   │   └── analyze.ts        # API route handlers
│   ├── services/
│   │   └── gemini.ts         # Gemini AI integration
│   └── types/
│       └── index.ts          # TypeScript types
├── test-api.js               # Node.js test script
├── test.html                 # Browser-based API tester (RECOMMENDED)
├── package.json
├── tsconfig.json
├── .env                      # Environment variables (not in git)
├── .env.example              # Example env file
└── vercel.json               # Vercel deployment config
```

## 🚀 Deployment

### Deploy to Vercel (Recommended)

1. **Install Vercel CLI:**
   ```bash
   npm install -g vercel
   ```

2. **Login to Vercel:**
   ```bash
   vercel login
   ```

3. **Deploy:**
   ```bash
   vercel
   ```

4. **Set environment variables:**
   ```bash
   vercel env add GEMINI_API_KEY
   # Paste your API key when prompted
   ```

5. **Deploy to production:**
   ```bash
   vercel --prod
   ```

Your API will be available at: `https://tapcal-backend.vercel.app`

### Deploy to Google Cloud Run

1. **Build Docker image:**
   ```bash
   gcloud builds submit --tag gcr.io/PROJECT_ID/tapcal-backend
   ```

2. **Deploy:**
   ```bash
   gcloud run deploy tapcal-backend \
     --image gcr.io/PROJECT_ID/tapcal-backend \
     --platform managed \
     --region us-central1 \
     --set-env-vars GEMINI_API_KEY=your_key_here
   ```

### Deploy to Railway.app

1. Create account at [railway.app](https://railway.app)
2. Click "New Project" → "Deploy from GitHub"
3. Select your repository
4. Add environment variable: `GEMINI_API_KEY`
5. Deploy!

## 🔧 Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `GEMINI_API_KEY` | ✅ Yes | - | Your Google Gemini API key |
| `PORT` | No | 3000 | Server port |
| `NODE_ENV` | No | development | Environment (development/production) |

### CORS Configuration

By default, CORS is open (`origin: '*'`) for development. For production, update in `src/index.ts`:

```typescript
app.use(cors({
  origin: 'https://yourdomain.com',
  methods: ['GET', 'POST'],
}));
```

## 🐛 Troubleshooting

### "GEMINI_API_KEY is not set"
- Make sure `.env` file exists in the backend root
- Verify the API key is set: `cat .env`
- Restart the dev server after changing `.env`

### "Module not found" errors
- Run `npm install` again
- Delete `node_modules` and reinstall: `rm -rf node_modules && npm install`

### CORS errors from Flutter app
- Make sure CORS is enabled in `src/index.ts`
- Check that the Flutter app is sending the correct Content-Type header

### "Invalid image data"
- Ensure base64 string is properly encoded
- Check that the image isn't too large (max 10MB)
- Verify the base64 string doesn't have invalid characters

## 📊 Performance

- Average response time: 2-4 seconds (depends on Gemini API)
- Image size limit: 10MB
- Recommended image size: 200x200px - 400x400px
- Concurrent requests: Handled by Node.js event loop

## 🔐 Security Notes

- **API Key**: Never commit `.env` to git
- **Rate Limiting**: Consider adding rate limiting for production
- **Authentication**: Add API authentication for production use
- **CORS**: Restrict origins in production

## 📝 Next Steps

1. ✅ Backend API is ready
2. ⏭️ Test with Postman/curl
3. ⏭️ Deploy to Vercel
4. ⏭️ Build Flutter app (Phase 2)
5. ⏭️ Integrate Flutter app with this API

## 🤝 Contributing

This is part of the TapCal project. See main README for contribution guidelines.

## 📄 License

MIT License - See main project LICENSE file.

