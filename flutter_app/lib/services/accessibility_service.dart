import 'package:flutter/services.dart';
import '../models/calendar_event.dart';

/// Service for managing the Accessibility Service with floating button
class AccessibilityService {
  static const MethodChannel _channel = MethodChannel('com.tapcal/accessibility');
  static Function(String base64Image)? onScreenCaptured;

  /// Initialize the service and set up listeners
  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onScreenCaptured':
          print('[Accessibility] Screenshot received!');
          final String? base64Image = call.arguments as String?;
          if (base64Image != null && onScreenCaptured != null) {
            onScreenCaptured!(base64Image);
          }
          break;
      }
    });
  }

  /// Check if accessibility service is enabled
  static Future<bool> isEnabled() async {
    try {
      final bool result = await _channel.invokeMethod('isAccessibilityEnabled');
      return result;
    } catch (e) {
      print('[Accessibility] Error checking status: $e');
      return false;
    }
  }

  /// Open accessibility settings so user can enable the service
  static Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      print('[Accessibility] Error opening settings: $e');
    }
  }

  /// Show the floating button
  static Future<void> showFloatingButton() async {
    try {
      await _channel.invokeMethod('showFloatingButton');
    } catch (e) {
      print('[Accessibility] Error showing button: $e');
    }
  }

  /// Hide the floating button
  static Future<void> hideFloatingButton() async {
    try {
      await _channel.invokeMethod('hideFloatingButton');
    } catch (e) {
      print('[Accessibility] Error hiding button: $e');
    }
  }

  /// Tell native side analysis is complete - shows button again
  static Future<void> analysisComplete() async {
    try {
      await _channel.invokeMethod('analysisComplete');
      print('[Accessibility] Analysis complete, button restored');
    } catch (e) {
      print('[Accessibility] Error: $e');
    }
  }

  /// Open the default calendar app with event details pre-filled
  static Future<void> openCalendarWithEvent({
    required String title,
    required String date,
    required String time,
    String? location,
    String? description,
  }) async {
    try {
      await _channel.invokeMethod('openCalendarWithEvent', {
        'title': title,
        'date': date,
        'time': time,
        'location': location,
        'description': description,
      });
      print('[Accessibility] Calendar app opened with event');
    } catch (e) {
      print('[Accessibility] Error opening calendar: $e');
    }
  }

  /// Show detected events as swipeable cards overlay at the bottom of screen
  /// This works as an overlay without leaving the current app
  static Future<void> showEventsOverlay(List<CalendarEvent> events) async {
    try {
      // Convert events to list of maps for native
      final eventsList = events.map((e) => {
        'title': e.title,
        'date': e.date,
        'time': e.time,
        'location': e.location ?? '',
        'description': e.description ?? '',
      }).toList();
      
      await _channel.invokeMethod('showEventsOverlay', {
        'events': eventsList,
      });
      print('[Accessibility] Events overlay shown with ${events.length} events');
    } catch (e) {
      print('[Accessibility] Error showing events overlay: $e');
    }
  }
}
