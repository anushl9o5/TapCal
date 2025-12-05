# TapCal Android Prototype Roadmap

## 📋 Current State Analysis

### What You Have
Your TypeScript webapp prototype successfully demonstrates:
- ✅ Triple-tap gesture detection
- ✅ ROI (Region of Interest) cropping at tap location
- ✅ Gemini 2.5 Flash API integration
- ✅ Structured calendar event extraction
- ✅ Modern UI with overlay for event confirmation

### Current Tech Stack
- **Frontend**: React + TypeScript
- **AI Service**: Google Gemini API (`@google/genai`)
- **Deployment**: Browser-based (Vite dev server)

---

## 🏗️ Architecture Options for Android

### Option A: Backend API + Flutter Frontend (RECOMMENDED FOR PROTOTYPING)

**Architecture:**
```
Android App (Flutter/Dart)
    ↓ (HTTP/REST)
Backend API (TypeScript/Node.js)
    ↓
Gemini API
```

**Advantages:**
- ✅ Reuse ALL existing TypeScript logic (no rewriting)
- ✅ Faster prototyping - focus on Android UI/UX only
- ✅ Secure API key (never exposed to client)
- ✅ Easy debugging in familiar TypeScript environment
- ✅ Can iterate on AI prompts without rebuilding app
- ✅ Easier logging, monitoring, and error handling
- ✅ Can add rate limiting, caching, user management later

**Disadvantages:**
- ⚠️ Requires backend hosting (free tier available)
- ⚠️ Network latency (but AI call itself is network-bound anyway)
- ⚠️ Requires internet connection

**Best For:** Fast prototyping, testing, MVP, demos

---

### Option B: Native Dart/Flutter Implementation

**Architecture:**
```
Android App (Flutter/Dart)
    ↓ (Direct HTTP)
Gemini API
```

**Advantages:**
- ✅ Single codebase
- ✅ No backend infrastructure needed
- ✅ Slightly lower latency (one less hop)

**Disadvantages:**
- ⚠️ Must rewrite all TypeScript logic in Dart
- ⚠️ API key management complexity (need to secure it)
- ⚠️ Harder to debug AI responses
- ⚠️ Every prompt change requires app rebuild
- ⚠️ More work upfront

**Best For:** Production apps, when logic is finalized

---

## 🚀 Recommended Approach: Hybrid Prototyping

### Phase 1: Backend API (1-2 days)
Keep your TypeScript logic, expose it as API endpoints.

### Phase 2: Flutter Frontend (2-3 days)
Build Android-specific UI and gestures.

### Phase 3: Native Migration (Later, if needed)
Once everything works and is tested, optionally migrate to pure Dart.

---

## 📝 Detailed Implementation Plan

### PHASE 1: Create Backend API

#### Step 1.1: Set up Node.js/Express Backend
**Location:** `/TapCal/backend/`

**Files to create:**
```
backend/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts          # Express server
│   ├── routes/
│   │   └── analyze.ts    # POST /analyze endpoint
│   ├── services/
│   │   └── gemini.ts     # (Copy from your current geminiService.ts)
│   └── types/
│       └── index.ts      # (Copy from your current types.ts)
├── .env                  # API_KEY=your_gemini_key
└── README.md
```

**Endpoints to implement:**
```typescript
POST /api/analyze
Body: {
  "image": "base64_encoded_image_data",
  "context": "messaging|email|browser"  // Optional
}

Response: {
  "success": true,
  "event": {
    "title": "Meeting with Sarah",
    "date": "2024-05-21",
    "time": "14:00",
    "location": "Conference Room",
    "description": "Discuss Q2 roadmap"
  }
}
```

**Key tasks:**
- [ ] Initialize Node.js project
- [ ] Copy `geminiService.ts` logic (already done!)
- [ ] Add Express routes
- [ ] Add CORS for Flutter app
- [ ] Add error handling
- [ ] Test with Postman/curl

**Estimated time:** 4-6 hours

---

#### Step 1.2: Deploy Backend (Multiple options)

**Free hosting options:**
1. **Vercel** (easiest, 5 minutes)
   - Zero config for Node.js
   - Automatic HTTPS
   - Free tier: Generous

2. **Google Cloud Run** (best for production)
   - Auto-scaling
   - Pay per request
   - Free tier: 2 million requests/month

3. **Railway.app** (good balance)
   - Simple deployment
   - Environment variables
   - Free tier available

**Recommended:** Start with **Vercel** for fastest setup.

**Key tasks:**
- [ ] Choose hosting platform
- [ ] Deploy backend
- [ ] Get public URL (e.g., `https://tapcal-api.vercel.app`)
- [ ] Test endpoint from browser/Postman

**Estimated time:** 1-2 hours

---

### PHASE 2: Build Flutter Android App

#### Step 2.1: Initialize Flutter Project
**Location:** `/TapCal/flutter_app/`

```bash
flutter create tapcal_flutter
cd tapcal_flutter
```

**Key dependencies to add:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0                    # For API calls
  image_picker: ^1.0.0            # For screenshot capture
  screenshot: ^2.1.0              # For taking screenshots
  permission_handler: ^11.0.0     # For screen capture permissions
  intl: ^0.18.0                   # For date formatting
```

**Key tasks:**
- [ ] Initialize Flutter project
- [ ] Add dependencies
- [ ] Set up Android permissions in `AndroidManifest.xml`
- [ ] Test basic app runs on emulator

**Estimated time:** 1 hour

---

#### Step 2.2: Implement Core Features

##### Feature 1: Triple-Tap Detection
**File:** `lib/widgets/triple_tap_detector.dart`

**What it needs:**
- Gesture detector with timing logic
- Visual feedback (ripple effect)
- Callback to parent widget

**Implementation notes:**
```dart
class TripleTapDetector extends StatefulWidget {
  final Widget child;
  final Function(Offset) onTripleTap;
  
  // Logic:
  // - Track tap count and timestamps
  // - Reset after 600ms (your DOUBLE_TAP_DELAY)
  // - Show ripple animation on each tap
  // - Fire callback on 3rd tap
}
```

---

##### Feature 2: Screenshot Capture & ROI Cropping
**File:** `lib/services/screenshot_service.dart`

**What it needs:**
- Capture current screen (or specific widget)
- Crop around tap coordinates
- Convert to base64

**Android-specific considerations:**
- Need `android.permission.READ_MEDIA_VISUAL_USER_SELECTED` (Android 14+)
- Or use accessibility service for system-wide capture
- For prototype: Use screenshot of your app's content only

**Implementation options:**
1. **Simple approach (for prototype):**
   - Use `screenshot` package to capture app content
   - Crop programmatically using `image` package
   
2. **System-wide approach (for production):**
   - Use Media Projection API (requires user permission)
   - Or Accessibility Service (more complex)

---

##### Feature 3: API Integration
**File:** `lib/services/api_service.dart`

```dart
class ApiService {
  static const String baseUrl = 'https://tapcal-api.vercel.app';
  
  Future<CalendarEvent?> analyzeImage(String base64Image) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/analyze'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image': base64Image}),
    );
    
    if (response.statusCode == 200) {
      return CalendarEvent.fromJson(jsonDecode(response.body)['event']);
    }
    return null;
  }
}
```

---

##### Feature 4: Calendar Integration
**File:** `lib/services/calendar_service.dart`

**Add dependency:**
```yaml
dependencies:
  device_calendar: ^4.8.0  # For accessing native calendar
```

**What it needs:**
- Request calendar permissions
- Insert event into default calendar app
- Handle success/failure

```dart
class CalendarService {
  Future<bool> addEvent(CalendarEvent event) async {
    // 1. Request permission
    final calendarsResult = await deviceCalendarPlugin.retrieveCalendars();
    
    // 2. Get default calendar (or let user choose)
    final calendar = calendarsResult.data?.first;
    
    // 3. Create event
    final calendarEvent = Event(
      calendar.id,
      title: event.title,
      start: DateTime.parse('${event.date} ${event.time}'),
      description: event.description,
    );
    
    // 4. Save
    return await deviceCalendarPlugin.createOrUpdateEvent(calendarEvent);
  }
}
```

---

##### Feature 5: UI Components
**Files:**
```
lib/
├── main.dart                    # App entry point
├── screens/
│   ├── home_screen.dart         # Main screen (shows current app content)
│   └── event_preview_screen.dart # Bottom sheet for event confirmation
├── widgets/
│   ├── triple_tap_detector.dart
│   └── loading_overlay.dart
└── services/
    ├── api_service.dart
    ├── screenshot_service.dart
    └── calendar_service.dart
```

**Key UI elements:**
- Transparent overlay (always listening for triple-tap)
- Loading indicator during analysis
- Bottom sheet modal for event preview
- Edit fields for title, date, time, location
- "Save to Calendar" button

---

#### Step 2.3: Android-Specific Setup

**AndroidManifest.xml additions:**
```xml
<uses-permission android:name="android.permission.READ_CALENDAR" />
<uses-permission android:name="android.permission.WRITE_CALENDAR" />
<uses-permission android:name="android.permission.INTERNET" />

<!-- For system-wide screenshot (if you go that route): -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
```

**Key tasks:**
- [ ] Add permissions
- [ ] Configure app to run as overlay (if needed)
- [ ] Set minimum SDK version (e.g., 24 / Android 7.0)

**Estimated time:** 30 minutes

---

### PHASE 3: Testing & Refinement

#### Test Scenarios
1. **Triple-tap detection:**
   - [ ] Single tap (no action)
   - [ ] Double tap (no action)
   - [ ] Triple tap (triggers analysis)
   - [ ] Slow taps (should reset)

2. **ROI cropping:**
   - [ ] Tap center of screen
   - [ ] Tap near edges (ensure crop doesn't go out of bounds)
   - [ ] Different screen sizes

3. **API integration:**
   - [ ] Successful analysis
   - [ ] Network error handling
   - [ ] Invalid image format
   - [ ] Timeout handling

4. **Calendar integration:**
   - [ ] Permission denied
   - [ ] Permission granted → save success
   - [ ] Edit event before saving
   - [ ] Cancel without saving

**Estimated time:** 2-3 hours

---

## 🎯 Simplified Prototype Scope

For fastest results, simplify to:

### Minimal Viable Prototype (MVP)
**What to include:**
- ✅ Display static screenshot from your existing webapp
- ✅ Triple-tap detection on that image
- ✅ Send cropped region to backend API
- ✅ Display extracted event in bottom sheet
- ✅ "Save to Calendar" button (with system intent)

**What to skip for now:**
- ❌ Real-time screen capture (complex)
- ❌ System-wide overlay (requires accessibility service)
- ❌ Multiple app contexts
- ❌ User authentication

**Result:** Working prototype in 1-2 days

---

## 🛠️ Technical Considerations

### 1. System-Wide Screen Capture Challenge
**Problem:** Android restricts background screen capture for security.

**Solutions:**
- **Accessibility Service:** Most reliable, but requires user setup
- **Media Projection API:** Prompts user each time
- **Overlay Window:** Can only capture your own app content

**For prototype:** Use screenshot of your own app displaying content.

**For production:** Implement Accessibility Service (better UX after one-time setup).

---

### 2. API Key Security
**Problem:** Never expose Gemini API key in Flutter app (can be extracted).

**Solution:** Backend API handles key (already solved with Option A).

---

### 3. ROI Size Optimization
Current: 200x200px (from your `constants.ts`)

**Considerations:**
- Larger = better text recognition, but slower upload/analysis
- Smaller = faster, but may miss context

**Recommendation:** Test with 200x200, 300x300, 400x400 and compare.

---

### 4. Offline Support (Future)
**Option 1:** Cache recent screens locally, queue for later
**Option 2:** On-device ML model (TFLite) for initial extraction

**For prototype:** Require internet connection.

---

## 📦 File Structure Summary

```
TapCal/
├── TypeScript WebApp/           # Your current prototype (keep as reference)
├── backend/                     # NEW: Express API
│   ├── src/
│   │   ├── index.ts
│   │   ├── routes/
│   │   └── services/
│   ├── package.json
│   └── .env
├── flutter_app/                 # NEW: Android app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   ├── widgets/
│   │   ├── services/
│   │   └── models/
│   ├── android/
│   ├── pubspec.yaml
│   └── README.md
└── ANDROID_PROTOTYPE_ROADMAP.md # This file
```

---

## ⏱️ Time Estimates

| Phase | Task | Time |
|-------|------|------|
| 1.1 | Backend API setup | 4-6 hours |
| 1.2 | Deploy backend | 1-2 hours |
| 2.1 | Flutter project init | 1 hour |
| 2.2 | Core features implementation | 8-12 hours |
| 2.3 | Android setup | 30 mins |
| 3 | Testing & refinement | 2-3 hours |
| **Total** | **MVP Prototype** | **17-25 hours** |

**Realistic timeline:** 3-4 days (part-time) or 2 days (full-time)

---

## 🎬 Next Steps (What to Do Right Now)

1. **Review this document** - Make sure you agree with the approach
2. **Decide:** Backend + Flutter (recommended) vs Pure Dart/Flutter
3. **Set up backend** - I can help scaffold the Express API
4. **Initialize Flutter project** - Set up basic structure
5. **Test integration** - Verify API works from Flutter

---

## 🤔 Questions to Consider

Before starting, decide:
- [ ] Do you have a Gemini API key with quota?
- [ ] Which hosting platform for backend? (Vercel recommended)
- [ ] Test on real device or emulator? (Real device recommended for gestures)
- [ ] Target Android version? (Recommend min SDK 24, target 34)
- [ ] System-wide capture needed for MVP? (Suggest: no, for faster prototype)

---

## 💡 Pro Tips

1. **Start with the backend API first** - It's the quickest win and validates your logic works
2. **Use Postman/Insomnia** - Test API before building Flutter app
3. **Flutter DevTools** - Use for debugging network calls
4. **Test on real device** - Gestures behave differently than emulator
5. **Keep TypeScript webapp running** - Great reference for UI/UX

---

## 📚 Resources

### Backend (TypeScript/Node.js)
- Express.js: https://expressjs.com/
- Vercel deployment: https://vercel.com/docs
- Google GenAI SDK: https://www.npmjs.com/package/@google/genai

### Flutter
- Flutter docs: https://docs.flutter.dev/
- Gesture detection: https://docs.flutter.dev/cookbook/gestures/
- Device calendar plugin: https://pub.dev/packages/device_calendar
- Screenshot capture: https://pub.dev/packages/screenshot

### Android
- Media Projection API: https://developer.android.com/media/platform/media-projection
- Accessibility Service: https://developer.android.com/guide/topics/ui/accessibility/service

---

## ✅ Success Criteria

Your prototype is successful when:
- [ ] User can triple-tap on simulated screen content
- [ ] App crops and sends image to backend
- [ ] Gemini extracts calendar event correctly
- [ ] User can review and edit event details
- [ ] Event saves to device calendar
- [ ] Entire flow completes in < 5 seconds

---

**Ready to start?** Let me know which phase you'd like to begin with, and I'll help you set it up!

