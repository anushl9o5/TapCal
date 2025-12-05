/// Calendar event model matching the backend API response
class CalendarEvent {
  final String title;
  final String date;
  final String time;
  final String? location;
  final String? description;

  CalendarEvent({
    required this.title,
    required this.date,
    required this.time,
    this.location,
    this.description,
  });

  /// Create from JSON (API response)
  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      title: json['title'] ?? 'Untitled Event',
      date: json['date'] ?? '',
      time: json['time'] ?? '09:00',
      location: json['location'],
      description: json['description'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'date': date,
      'time': time,
      'location': location,
      'description': description,
    };
  }

  /// Parse date string to DateTime
  DateTime? get dateTime {
    try {
      String normalizedTime = time
          .replaceAll('AM', '')
          .replaceAll('PM', '')
          .replaceAll('am', '')
          .replaceAll('pm', '')
          .trim();
      
      if (normalizedTime.contains('-')) {
        normalizedTime = normalizedTime.split('-')[0].trim();
      }
      
      int hour = int.parse(normalizedTime.split(':')[0]);
      int minute = int.parse(normalizedTime.split(':')[1].replaceAll(RegExp(r'[^0-9]'), ''));
      
      if (time.toLowerCase().contains('pm') && hour < 12) {
        hour += 12;
      } else if (time.toLowerCase().contains('am') && hour == 12) {
        hour = 0;
      }
      
      final dateParts = date.split('-');
      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        hour,
        minute,
      );
    } catch (e) {
      print('Error parsing date/time: $e');
      return null;
    }
  }

  CalendarEvent copyWith({
    String? title,
    String? date,
    String? time,
    String? location,
    String? description,
  }) {
    return CalendarEvent(
      title: title ?? this.title,
      date: date ?? this.date,
      time: time ?? this.time,
      location: location ?? this.location,
      description: description ?? this.description,
    );
  }

  @override
  String toString() {
    return 'CalendarEvent(title: $title, date: $date, time: $time, location: $location)';
  }
}

