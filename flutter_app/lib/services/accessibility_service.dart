import 'package:flutter/services.dart';
import '../models/calendar_event.dart';

/// Service for managing the Accessibility Service with notification-based capture
class AccessibilityService {
  static const MethodChannel _channel = MethodChannel('com.tapcal/accessibility');

  /// Initialize the service (no longer needs screen capture callback)
  static void initialize() {
    // No-op for now - notification-based flow stores events in SharedPreferences
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

  /// Start the notification service (called when accessibility is enabled)
  static Future<void> startNotificationService() async {
    try {
      await _channel.invokeMethod('startNotificationService');
      print('[Accessibility] Notification service started');
    } catch (e) {
      print('[Accessibility] Error starting notification service: $e');
    }
  }

  /// Stop the notification service
  static Future<void> stopNotificationService() async {
    try {
      await _channel.invokeMethod('stopNotificationService');
      print('[Accessibility] Notification service stopped');
    } catch (e) {
      print('[Accessibility] Error stopping notification service: $e');
    }
  }

  /// Check if notification service is running
  static Future<bool> isNotificationServiceRunning() async {
    try {
      final bool result = await _channel.invokeMethod('isNotificationServiceRunning');
      return result;
    } catch (e) {
      print('[Accessibility] Error checking notification service: $e');
      return false;
    }
  }

  /// Open the default calendar app with event details pre-filled
  static Future<void> openCalendarWithEvent(CalendarEvent event) async {
    try {
      await _channel.invokeMethod('openCalendarWithEvent', {
        'title': event.title,
        'date': event.date,
        'time': event.time,
        'location': event.location,
        'description': event.description,
      });
      print('[Accessibility] Calendar app opened with event');
    } catch (e) {
      print('[Accessibility] Error opening calendar: $e');
    }
  }
}
