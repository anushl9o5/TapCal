import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/calendar_event.dart';

/// Service for communicating with the SnapCal backend API
class ApiService {
  static const String baseUrl = 'https://tap-cal-git-main-anush-kumars-projects-fdf1b16c.vercel.app';

  static Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print('[API] Health check failed: $e');
      return false;
    }
  }

  /// Analyzes an image and returns ALL detected calendar events
  static Future<List<CalendarEvent>> analyzeImageForEvents(String base64Image, {String context = 'screenshot'}) async {
    try {
      print('[API] Sending image for multi-event analysis...');
      final startTime = DateTime.now();
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image': base64Image,
          'context': context,
        }),
      ).timeout(const Duration(seconds: 45)); // Longer timeout for multi-event

      final duration = DateTime.now().difference(startTime);
      print('[API] Response received in ${duration.inMilliseconds}ms');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['events'] != null) {
          final List<dynamic> eventsJson = data['events'];
          final events = eventsJson
              .map((e) => CalendarEvent.fromJson(e))
              .toList();
          print('[API] ${events.length} events detected');
          for (var event in events) {
            print('[API]   - ${event.title} @ ${event.date} ${event.time}');
          }
          return events;
        } else {
          print('[API] No events detected: ${data['error']}');
          return [];
        }
      } else {
        print('[API] Error response: ${response.statusCode}');
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      print('[API] Request failed: $e');
      rethrow;
    }
  }

  /// Legacy single event method - returns first event or null
  static Future<CalendarEvent?> analyzeImage(String base64Image, {String context = 'upload'}) async {
    final events = await analyzeImageForEvents(base64Image, context: context);
    return events.isNotEmpty ? events.first : null;
  }
}
