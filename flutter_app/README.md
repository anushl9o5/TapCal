# TapCal Flutter App

AI-powered calendar assistant. Triple-tap **anywhere** on your Android phone to create calendar events.

## 🚀 Features

- **System-wide triple-tap** - Works on any app (Chrome, Instagram, Messages, etc.)
- **AI-powered detection** - Gemini AI extracts dates, times, and event details
- **Instant calendar save** - One-tap to add to your device calendar
- **Privacy-focused** - Screenshots are only used for event detection

## 📱 How It Works

1. **Enable TapCal** in Accessibility Settings
2. **Open any app** (Chrome, Instagram, etc.)
3. **Triple-tap** on text that contains a date/time
4. **TapCal captures** the screen and analyzes it
5. **Review** the detected event
6. **Save** to your calendar!

## 🔧 Setup

### Prerequisites
- Flutter SDK 3.0+
- Android device/emulator

### Build & Run

```bash
cd flutter_app
flutter pub get
flutter run
```

### Enable Accessibility Service

1. Open TapCal app
2. Tap "Enable Triple-Tap" button
3. Find "TapCal" in Accessibility settings
4. Toggle it ON
5. Confirm "Allow"

## 🏗️ Architecture

```
lib/
├── main.dart                    # App entry
├── models/
│   └── calendar_event.dart      # Event model
├── screens/
│   ├── home_screen.dart         # Main UI
│   └── event_preview_screen.dart
├── services/
│   ├── api_service.dart         # Backend API
│   ├── accessibility_service.dart # Native bridge
│   └── calendar_service.dart    # Device calendar
└── widgets/
    └── loading_overlay.dart

android/app/src/main/kotlin/com/tapcal/tapcal_app/
├── MainActivity.kt              # Platform channel bridge
└── TapCalAccessibilityService.kt # Native accessibility service
```

## 🔐 Permissions

- **Accessibility** - To detect triple-tap anywhere
- **Screen Capture** - To capture what you tapped on
- **Calendar** - To save events
- **Internet** - To call the AI backend

## 📄 License

MIT

