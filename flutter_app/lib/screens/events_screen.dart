import 'package:flutter/material.dart';
import '../models/calendar_event.dart';
import '../models/event_history.dart';
import '../services/accessibility_service.dart';

class EventsScreen extends StatefulWidget {
  final List<CalendarEvent> events;
  
  const EventsScreen({super.key, required this.events});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late List<CalendarEvent> _events;
  
  @override
  void initState() {
    super.initState();
    _events = List.from(widget.events);
  }

  Future<void> _addToCalendar(CalendarEvent event) async {
    await AccessibilityService.openCalendarWithEvent(
      title: event.title,
      date: event.date,
      time: event.time,
      location: event.location,
      description: event.description,
    );
    
    await EventHistoryService.addEvent(event, saved: true);
    
    setState(() {
      _events.remove(event);
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text('Added: ${event.title}'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
    
    // Go back if no more events
    if (_events.isEmpty && mounted) {
      Navigator.pop(context);
    }
  }

  void _dismissEvent(CalendarEvent event) {
    setState(() {
      _events.remove(event);
    });
    
    if (_events.isEmpty && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detected Events',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_events.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
        ],
      ),
      body: _events.isEmpty
          ? _buildEmptyState()
          : _buildEventsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'All events added!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        return _buildEventCard(_events[index], index);
      },
    );
  }

  Widget _buildEventCard(CalendarEvent event, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 100)),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.1),
                    const Color(0xFF8B5CF6).withOpacity(0.05),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.event, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _dismissEvent(event),
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
            ),
            
            // Event details
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildDetailRow(Icons.calendar_today, 'Date', event.date),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.access_time, 'Time', event.time),
                  if (event.location != null && event.location!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.location_on, 'Location', event.location!),
                  ],
                  if (event.description != null && event.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.notes, 'Notes', event.description!),
                  ],
                  const SizedBox(height: 20),
                  
                  // Add button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _addToCalendar(event),
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      label: const Text(
                        'Add to Calendar',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF6366F1)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


