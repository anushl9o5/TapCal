import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/animated_card.dart';
import '../services/api_service.dart';
import '../services/accessibility_service.dart';
import '../models/calendar_event.dart';
import 'settings_screen.dart';

/// Event scan entry from native SharedPreferences
class ScanEntry {
  final DateTime timestamp;
  final List<CalendarEvent> events;
  
  ScanEntry({required this.timestamp, required this.events});
  
  factory ScanEntry.fromJson(Map<String, dynamic> json) {
    final eventsList = (json['events'] as List?) ?? [];
    return ScanEntry(
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int? ?? 0),
      events: eventsList.map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  static const _nativeChannel = MethodChannel('com.tapcal.tapcal_app/native');
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isAnalyzing = false;
  bool _isConnected = false;
  bool _isAccessibilityEnabled = false;
  bool _isNotificationEnabled = false;
  bool _isNotificationServiceRunning = false;
  List<ScanEntry> _scanHistory = [];
  
  // Track expanded/collapsed state for each scan entry
  Set<int> _expandedScans = {};
  
  // For opening calendar
  List<CalendarEvent> _pendingEvents = [];

  late AnimationController _headerController;
  late Animation<double> _headerAnimation;
  
  // Tab controller for Home/History
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    );
    
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _headerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllStatuses();
      _loadScanHistory();
    }
  }

  Future<void> _initialize() async {
    AccessibilityService.initialize();
    
    // Listen for tab switch requests from native
    const channel = MethodChannel('com.tapcal/accessibility');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'openTab' && call.arguments == 'history') {
        if (mounted) {
          setState(() => _currentTab = 1);
        }
      }
    });
    
    await _checkConnection();
    await _checkAllStatuses();
    await _loadScanHistory();
    
    _headerController.forward();
  }
  
  Future<void> _checkAllStatuses() async {
    await _checkAccessibilityStatus();
    await _checkNotificationPermission();
    await _checkNotificationServiceStatus();
  }
  
  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() => _isNotificationEnabled = status.isGranted);
    }
  }
  
  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    if (mounted) {
      setState(() => _isNotificationEnabled = status.isGranted);
      
      if (status.isGranted) {
        // Start notification service after permission granted
        await AccessibilityService.startNotificationService();
        await _checkNotificationServiceStatus();
      }
    }
  }
  
  Future<void> _checkNotificationServiceStatus() async {
    final running = await AccessibilityService.isNotificationServiceRunning();
    if (mounted) {
      setState(() => _isNotificationServiceRunning = running);
    }
  }

  Future<void> _checkConnection() async {
    final connected = await ApiService.healthCheck();
    if (mounted) setState(() => _isConnected = connected);
  }

  Future<void> _checkAccessibilityStatus() async {
    final enabled = await AccessibilityService.isEnabled();
    if (mounted) setState(() => _isAccessibilityEnabled = enabled);
  }

  /// Load scan history from native SharedPreferences
  Future<void> _loadScanHistory() async {
    try {
      // Read from native SharedPreferences
      final result = await _nativeChannel.invokeMethod('getScanHistory');
      if (result != null) {
        final List<dynamic> historyJson = jsonDecode(result as String);
        final entries = historyJson
            .map((e) => ScanEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        
        if (mounted) {
          setState(() => _scanHistory = entries);
        }
      }
    } catch (e) {
      print('[Home] Error loading scan history: $e');
      // Fallback - try Flutter SharedPreferences
      await _loadScanHistoryFallback();
    }
  }
  
  Future<void> _loadScanHistoryFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('tapcal_scan_history');
      if (historyJson != null) {
        final List<dynamic> history = jsonDecode(historyJson);
        final entries = history
            .map((e) => ScanEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) setState(() => _scanHistory = entries);
      }
    } catch (e) {
      print('[Home] Fallback history load error: $e');
    }
  }

  Future<void> _openCalendarWithEvent(CalendarEvent event) async {
    try {
      await AccessibilityService.openCalendarWithEvent(event);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Opening "${event.title}" in Calendar',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[Home] Error opening calendar: $e');
    }
  }

  Future<void> _pickAndAnalyzeImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() => _isAnalyzing = true);
        
        final bytes = await File(image.path).readAsBytes();
        final base64Image = base64Encode(bytes);
        
        try {
          final events = await ApiService.analyzeImageForEvents(base64Image);
          
          if (mounted) {
            setState(() {
              _isAnalyzing = false;
              if (events.isNotEmpty) {
                _pendingEvents = events;
                _currentTab = 1; // Switch to history tab
              }
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(events.isNotEmpty 
                    ? 'Found ${events.length} event${events.length > 1 ? 's' : ''}!'
                    : 'No events detected'),
                backgroundColor: events.isNotEmpty 
                    ? const Color(0xFF10B981) 
                    : const Color(0xFF6366F1),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isAnalyzing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[400]),
            );
          }
        }
      }
    } catch (e) {
      print('[Home] Error picking image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoadingOverlay(
        isLoading: _isAnalyzing,
        message: 'Looking for calendar events...',
        child: Column(
          children: [
            _buildAnimatedHeader(),
            Expanded(
              child: _currentTab == 0 
                  ? _buildHomeTab()
                  : _buildHistoryTab(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.history_rounded, 'History', badge: _scanHistory.isNotEmpty ? _scanHistory.length : null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {int? badge}) {
    final isSelected = _currentTab == index;
    
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFF6366F1) : Colors.grey[400],
                  size: 24,
                ),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge > 9 ? '9+' : badge.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: FloatingActionButton.extended(
            onPressed: _pickAndAnalyzeImage,
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Pick Image', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedHeader() {
    return FadeTransition(
      opacity: _headerAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.3),
          end: Offset.zero,
        ).animate(_headerAnimation),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            left: 24,
            right: 24,
            bottom: 28,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SnapCal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'AI Calendar Assistant',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  _buildConnectionBadge(),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                      _loadScanHistory();
                    },
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _isConnected 
            ? Colors.white.withOpacity(0.2)
            : Colors.red.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusDot(isActive: _isConnected),
          const SizedBox(width: 6),
          Text(
            _isConnected ? 'Online' : 'Offline',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          AnimatedCard(index: 0, child: _buildPrivacyCard()),
          const SizedBox(height: 16),
          AnimatedCard(index: 1, child: _buildStatusCard()),
          const SizedBox(height: 16),
          AnimatedCard(index: 2, child: _buildHowItWorksCard()),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final allReady = _isAccessibilityEnabled && _isNotificationEnabled && _isNotificationServiceRunning;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: allReady 
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    allReady ? Icons.check_circle_rounded : Icons.warning_rounded,
                    color: allReady 
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allReady ? 'Ready to Scan!' : 'Setup Required',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        allReady
                            ? 'Swipe down and tap SnapCal notification'
                            : 'Complete the steps below to start',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Step 1: Accessibility Permission
            _buildSetupStep(
              step: 1,
              title: 'Screen Capture',
              subtitle: 'Required to take screenshots',
              isComplete: _isAccessibilityEnabled,
              onTap: _isAccessibilityEnabled ? null : () => AccessibilityService.openSettings(),
              buttonText: 'Enable',
            ),
            
            const SizedBox(height: 12),
            
            // Step 2: Notification Permission
            _buildSetupStep(
              step: 2,
              title: 'Notifications',
              subtitle: 'Required for background capture',
              isComplete: _isNotificationEnabled,
              onTap: _isNotificationEnabled ? null : _requestNotificationPermission,
              buttonText: 'Allow',
            ),
            
            const SizedBox(height: 12),
            
            // Step 3: Service Running
            _buildSetupStep(
              step: 3,
              title: 'Notification Service',
              subtitle: _isNotificationServiceRunning ? 'Running in background' : 'Start the capture service',
              isComplete: _isNotificationServiceRunning,
              onTap: _isNotificationServiceRunning ? null : () async {
                await AccessibilityService.startNotificationService();
                await _checkNotificationServiceStatus();
              },
              buttonText: 'Start',
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSetupStep({
    required int step,
    required String title,
    required String subtitle,
    required bool isComplete,
    required VoidCallback? onTap,
    required String buttonText,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isComplete 
            ? const Color(0xFF10B981).withOpacity(0.05)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComplete 
              ? const Color(0xFF10B981).withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isComplete 
                  ? const Color(0xFF10B981)
                  : const Color(0xFF6366F1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isComplete
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                      '$step',
                      style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isComplete ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          if (!isComplete && onTap != null)
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF6366F1)),
                SizedBox(width: 10),
                Text(
                  'How It Works',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildStep('1', 'Swipe Down', 'Pull down notification shade'),
            _buildStep('2', 'Tap SnapCal', 'Tap the "SnapCal Ready" notification'),
            _buildStep('3', 'Wait', 'Notification shows "Looking for events..."'),
            _buildStep('4', 'Review', 'Come back here to add events to calendar'),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String stepNum, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                stepNum,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6366F1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy First',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Screenshots deleted immediately after analysis.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_scanHistory.isEmpty && _pendingEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 48,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No scans yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the notification to scan for events',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadScanHistory,
      color: const Color(0xFF6366F1),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _scanHistory.length + (_pendingEvents.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          // Show pending events first (always expanded)
          if (_pendingEvents.isNotEmpty && index == 0) {
            return AnimatedCard(
              index: 0,
              child: _buildScanCard(
                scanIndex: -1, // Special index for pending
                timestamp: DateTime.now(),
                events: _pendingEvents,
                isPending: true,
                isExpanded: true,
                onToggle: () {},
                onDeleteEvent: (event) {
                  setState(() {
                    _pendingEvents.remove(event);
                  });
                },
              ),
            );
          }
          
          final scanIndex = _pendingEvents.isNotEmpty ? index - 1 : index;
          final entry = _scanHistory[scanIndex];
          final isExpanded = _expandedScans.contains(scanIndex);
          
          return AnimatedCard(
            index: index,
            child: _buildScanCard(
              scanIndex: scanIndex,
              timestamp: entry.timestamp,
              events: entry.events,
              isExpanded: isExpanded,
              onToggle: () {
                setState(() {
                  if (isExpanded) {
                    _expandedScans.remove(scanIndex);
                  } else {
                    _expandedScans.add(scanIndex);
                  }
                });
              },
              onDeleteEvent: (event) => _deleteEventFromHistory(scanIndex, event),
            ),
          );
        },
      ),
    );
  }
  
  Future<void> _deleteEventFromHistory(int scanIndex, CalendarEvent event) async {
    setState(() {
      _scanHistory[scanIndex].events.remove(event);
      // If no events left in this scan, remove the entire scan entry
      if (_scanHistory[scanIndex].events.isEmpty) {
        _scanHistory.removeAt(scanIndex);
        _expandedScans.remove(scanIndex);
        // Adjust expanded indices
        _expandedScans = _expandedScans
            .map((i) => i > scanIndex ? i - 1 : i)
            .toSet();
      }
    });
    
    // Save updated history to native SharedPreferences
    await _saveHistoryToNative();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Event removed'),
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  
  Future<void> _saveHistoryToNative() async {
    try {
      final historyJson = _scanHistory.map((entry) => {
        'timestamp': entry.timestamp.millisecondsSinceEpoch,
        'events': entry.events.map((e) => {
          'title': e.title,
          'date': e.date,
          'time': e.time,
          'location': e.location,
          'description': e.description,
        }).toList(),
      }).toList();
      
      await _nativeChannel.invokeMethod('saveHistory', jsonEncode(historyJson));
    } catch (e) {
      print('[Home] Error saving history: $e');
    }
  }

  Widget _buildScanCard({
    required int scanIndex,
    required DateTime timestamp,
    required List<CalendarEvent> events,
    bool isPending = false,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Function(CalendarEvent) onDeleteEvent,
  }) {
    final timeAgo = _formatTimeAgo(timestamp);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isPending 
            ? Border.all(color: const Color(0xFF10B981), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header (always visible, tappable to expand/collapse)
          InkWell(
            onTap: isPending ? null : onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Expand/Collapse icon
                  if (!isPending)
                    AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey[400],
                        size: 24,
                      ),
                    ),
                  if (!isPending) const SizedBox(width: 8),
                  
                  // Timestamp
                  Expanded(
                    child: Row(
                      children: [
                        if (isPending)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Event count badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${events.length} event${events.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Events list (collapsible)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: events.map((event) => _buildEventItem(
                  event: event,
                  onDelete: () => onDeleteEvent(event),
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventItem({
    required CalendarEvent event,
    required VoidCallback onDelete,
  }) {
    return Dismissible(
      key: Key('${event.title}_${event.date}_${event.time}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        event.date,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      if (event.time.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          event.time,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                  if (event.location != null && event.location!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location!,
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => _openCalendarWithEvent(event),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16),
                  SizedBox(width: 4),
                  Text('Add', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${timestamp.month}/${timestamp.day}';
  }
}

class _StatusDot extends StatefulWidget {
  final bool isActive;
  const _StatusDot({required this.isActive});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isActive) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Container(
        width: 8, height: 8,
        decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.5 * _animation.value),
                blurRadius: 4 * _animation.value,
                spreadRadius: 1 * _animation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
