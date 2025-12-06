# App Icons

Place your app icons in this folder:

## Required Files

1. **app_icon.png** - 1024x1024px square icon (main app icon)
2. **app_icon_foreground.png** - 1024x1024px icon foreground for Android adaptive icons (with transparency)
3. **splash_icon.png** - 512x512px icon for splash screen (can have transparency)

## Quick Generation

You can use any online tool to create these icons:
- https://icon.kitchen - Free app icon generator
- https://www.canva.com - Design tool

## Color Scheme

- Primary: #6366F1 (Indigo)
- Secondary: #8B5CF6 (Purple)
- Accent: #10B981 (Emerald)

## Apply Icons

After adding your icons, run:

```bash
cd /Users/anush.kumar/Desktop/TapCal/flutter_app

# Generate launcher icons
flutter pub run flutter_launcher_icons

# Generate splash screen
flutter pub run flutter_native_splash:create
```

