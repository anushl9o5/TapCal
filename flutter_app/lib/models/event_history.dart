import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'calendar_event.dart';

class EventHistoryItem {
  final CalendarEvent event;
  final DateTime detectedAt;
  final bool savedToCalendar;

  EventHistoryItem({
    required this.event,
    required this.detectedAt,
    this.savedToCalendar = false,
  });

  Map<String, dynamic> toJson() => {
    'event': {
      'title': event.title,
      'date': event.date,
      'time': event.time,
      'location': event.location,
      'description': event.description,
    },
    'detectedAt': detectedAt.toIso8601String(),
    'savedToCalendar': savedToCalendar,
  };

  factory EventHistoryItem.fromJson(Map<String, dynamic> json) {
    final eventJson = json['event'] as Map<String, dynamic>;
    return EventHistoryItem(
      event: CalendarEvent(
        title: eventJson['title'] ?? '',
        date: eventJson['date'] ?? '',
        time: eventJson['time'] ?? '',
        location: eventJson['location'],
        description: eventJson['description'],
      ),
      detectedAt: DateTime.parse(json['detectedAt']),
      savedToCalendar: json['savedToCalendar'] ?? false,
    );
  }
}

class EventHistoryService {
  static const String _historyKey = 'event_history';
  static const int _maxItems = 20; // Keep last 20 events

  static Future<List<EventHistoryItem>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyJson = prefs.getString(_historyKey);
      
      if (historyJson == null) return [];
      
      final List<dynamic> decoded = jsonDecode(historyJson);
      return decoded
          .map((item) => EventHistoryItem.fromJson(item))
          .toList()
          ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    } catch (e) {
      print('[History] Error loading: $e');
      return [];
    }
  }

  static Future<void> addEvent(CalendarEvent event, {bool saved = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getHistory();
      
      // Add new item at the beginning
      history.insert(0, EventHistoryItem(
        event: event,
        detectedAt: DateTime.now(),
        savedToCalendar: saved,
      ));
      
      // Trim to max items
      final trimmed = history.take(_maxItems).toList();
      
      // Save
      final encoded = jsonEncode(trimmed.map((e) => e.toJson()).toList());
      await prefs.setString(_historyKey, encoded);
      
      print('[History] Event added: ${event.title}');
    } catch (e) {
      print('[History] Error saving: $e');
    }
  }

  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
      print('[History] Cleared');
    } catch (e) {
      print('[History] Error clearing: $e');
    }
  }
}

