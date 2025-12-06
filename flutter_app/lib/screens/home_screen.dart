import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/animated_card.dart';
import '../services/api_service.dart';
import '../services/accessibility_service.dart';
import '../models/calendar_event.dart';
import '../models/event_history.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isAnalyzing = false;
  bool _isConnected = false;
  bool _isAccessibilityEnabled = false;
  List<EventHistoryItem> _history = [];
  
  // Detected events from last scan
  List<CalendarEvent> _detectedEvents = [];

  // Animation controllers
  late AnimationController _headerController;
  late Animation<double> _headerAnimation;

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
      _checkAccessibilityStatus();
      _loadHistory();
    }
  }

  Future<void> _initialize() async {
    AccessibilityService.initialize();
    AccessibilityService.onScreenCaptured = _onScreenCaptured;
    
    await _checkConnection();
    await _checkAccessibilityStatus();
    await _loadHistory();
    
    _headerController.forward();
  }

  Future<void> _checkConnection() async {
    final connected = await ApiService.healthCheck();
    if (mounted) setState(() => _isConnected = connected);
  }

  Future<void> _checkAccessibilityStatus() async {
    final enabled = await AccessibilityService.isEnabled();
    if (mounted) setState(() => _isAccessibilityEnabled = enabled);
  }

  Future<void> _loadHistory() async {
    final history = await EventHistoryService.getHistory();
    if (mounted) setState(() => _history = history);
  }

  void _onScreenCaptured(String base64Image) {
    print('[Home] Screenshot received from floating button');
    _analyzeImageForEvents(base64Image);
  }

  Future<void> _analyzeImageForEvents(String base64Image) async {
    if (_isAnalyzing) return;
    setState(() {
      _isAnalyzing = true;
      _detectedEvents = [];
    });

    try {
      final events = await ApiService.analyzeImageForEvents(base64Image);

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _detectedEvents = events;
        });

        if (events.isNotEmpty) {
          // Show success notification
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text('Found ${events.length} event${events.length > 1 ? 's' : ''}!'),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('No events detected'),
                ],
              ),
              backgroundColor: const Color(0xFF6366F1),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      print('[Home] Error: $e');
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      await AccessibilityService.analysisComplete();
    }
  }

  Future<void> _addEventToCalendar(CalendarEvent event) async {
    await AccessibilityService.openCalendarWithEvent(
      title: event.title,
      date: event.date,
      time: event.time,
      location: event.location,
      description: event.description,
    );
    
    // Save to history
    await EventHistoryService.addEvent(event, saved: true);
    await _loadHistory();
    
    // Remove from detected list
    setState(() {
      _detectedEvents.remove(event);
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text('Adding: ${event.title}'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _dismissEvent(CalendarEvent event) {
    setState(() {
      _detectedEvents.remove(event);
    });
  }

  Future<void> _pickAndAnalyzeImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image != null) {
        final bytes = await File(image.path).readAsBytes();
        final base64Image = base64Encode(bytes);
        await _analyzeImageForEvents(base64Image);
      }
    } catch (e) {
      print('[Home] Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoadingOverlay(
        isLoading: _isAnalyzing,
        message: 'Looking for calendar events...',
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildAnimatedHeader()),
            
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Detected Events (priority display)
                  if (_detectedEvents.isNotEmpty) ...[
                    AnimatedCard(
                      index: 0,
                      child: _buildDetectedEventsCard(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  AnimatedCard(
                    index: _detectedEvents.isNotEmpty ? 1 : 0,
                    child: _buildStatusCard(),
                  ),
                  const SizedBox(height: 16),
                  
                  AnimatedCard(
                    index: _detectedEvents.isNotEmpty ? 2 : 1,
                    child: _buildHowToUseCard(),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_history.isNotEmpty) ...[
                    AnimatedCard(
                      index: _detectedEvents.isNotEmpty ? 3 : 2,
                      child: _buildHistorySection(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  AnimatedCard(
                    index: _detectedEvents.isNotEmpty ? 4 : 3,
                    child: _buildPrivacyCard(),
                  ),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildAnimatedFAB(),
    );
  }

  Widget _buildDetectedEventsCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.event_available, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Events Detected!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_detectedEvents.length} event${_detectedEvents.length > 1 ? 's' : ''} found',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _detectedEvents = []),
                  child: Text(
                    'Clear',
                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Event cards
            ...List.generate(_detectedEvents.length, (index) {
              final event = _detectedEvents[index];
              return _buildDetectedEventItem(event, index);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectedEventItem(CalendarEvent event, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 100)),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => _dismissEvent(event),
                  icon: Icon(Icons.close, color: Colors.grey[400], size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  event.date,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  event.time,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            if (event.location != null && event.location!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event.location!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _addEventToCalendar(event),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add to Calendar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedFAB() {
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
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
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
                      );
                    },
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TapCal',
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              const SettingsScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(1.0, 0.0),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              )),
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 300),
                        ),
                      );
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

  Widget _buildStatusCard() {
    final isEnabled = _isAccessibilityEnabled;
    
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
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isEnabled 
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isEnabled ? Icons.touch_app_rounded : Icons.touch_app_outlined,
                    color: isEnabled 
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
                        isEnabled ? 'Ready to Capture!' : 'Setup Required',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isEnabled
                            ? 'Tap the floating button on any screen'
                            : 'Enable accessibility to use floating button',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!isEnabled) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => AccessibilityService.openSettings(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.settings_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Enable Floating Button', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHowToUseCard() {
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
            _buildStepItem('📸', 'Capture', 'Tap the floating button'),
            _buildStepItem('🔍', 'Detect', 'AI finds all events'),
            _buildStepItem('✓', 'Choose', 'Add the events you want'),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(String emoji, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
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

  Widget _buildHistorySection() {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history_rounded, color: Color(0xFF6366F1)),
                    SizedBox(width: 10),
                    Text(
                      'Added Events',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...(_history.take(3).map((item) => _buildHistoryItem(item))),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(EventHistoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check, color: Color(0xFF10B981), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.event.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.event.date} ${item.event.time}',
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
