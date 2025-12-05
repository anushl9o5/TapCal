import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/loading_overlay.dart';
import '../services/api_service.dart';
import '../services/accessibility_service.dart';
import '../models/calendar_event.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isAnalyzing = false;
  bool _isConnected = false;
  bool _isAccessibilityEnabled = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check accessibility status when app resumes (user might have enabled it)
    if (state == AppLifecycleState.resumed) {
      _checkAccessibilityStatus();
    }
  }

  Future<void> _initialize() async {
    // Set up accessibility service callback
    AccessibilityService.initialize();
    AccessibilityService.onScreenCaptured = _onScreenCaptured;
    
    await _checkConnection();
    await _checkAccessibilityStatus();
  }

  Future<void> _checkConnection() async {
    final connected = await ApiService.healthCheck();
    if (mounted) setState(() => _isConnected = connected);
  }

  Future<void> _checkAccessibilityStatus() async {
    final enabled = await AccessibilityService.isEnabled();
    if (mounted) setState(() => _isAccessibilityEnabled = enabled);
  }

  /// Called when floating button captures a screen
  void _onScreenCaptured(String base64Image) {
    print('[Home] Screenshot received from floating button');
    _analyzeImage(base64Image);
  }

  Future<void> _analyzeImage(String base64Image) async {
    if (_isAnalyzing) return;
    setState(() => _isAnalyzing = true);

    try {
      final event = await ApiService.analyzeImage(base64Image);

      if (mounted) {
        setState(() => _isAnalyzing = false);

        if (event != null) {
          // Directly open the default calendar app with event details
          await AccessibilityService.openCalendarWithEvent(
            title: event.title,
            date: event.date,
            time: event.time,
            location: event.location,
            description: event.description,
          );
          
          // Show brief confirmation
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📅 Opening: ${event.title}'),
                backgroundColor: Colors.green[700],
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No calendar event detected')),
          );
        }
      }
    } catch (e) {
      print('[Home] Error: $e');
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      // IMPORTANT: Show floating button again after analysis completes
      await AccessibilityService.analysisComplete();
    }
  }

  Future<void> _pickAndAnalyzeImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
        final bytes = await File(image.path).readAsBytes();
        final base64Image = base64Encode(bytes);
        await _analyzeImage(base64Image);
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

  Future<void> _showAccessibilitySetup() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.touch_app, color: Colors.blue),
            SizedBox(width: 12),
            Text('Enable TapCal'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To show the floating capture button:\n',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('1. Tap "Open Settings" below'),
            SizedBox(height: 4),
            Text('2. Find "TapCal" in the list'),
            SizedBox(height: 4),
            Text('3. Toggle it ON'),
            SizedBox(height: 4),
            Text('4. Confirm "Allow"'),
            SizedBox(height: 16),
            Text(
              'A floating button will appear on all screens. Tap it to capture and analyze!',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              AccessibilityService.openSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TapCal'),
        centerTitle: true,
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              _isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isConnected ? Colors.greenAccent : Colors.redAccent,
              size: 20,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndAnalyzeImage,
        backgroundColor: Colors.blue[700],
        icon: const Icon(Icons.photo_library),
        label: const Text('Pick Screenshot'),
      ),
      body: LoadingOverlay(
        isLoading: _isAnalyzing,
        message: 'Analyzing with AI...',
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Accessibility Service Status Card
              _buildAccessibilityCard(),
              
              // Instructions
              _buildInstructionsCard(),
              
              // Quick Actions
              _buildQuickActionsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessibilityCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isAccessibilityEnabled ? Colors.green[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isAccessibilityEnabled ? Icons.check_circle : Icons.warning_amber,
                      color: _isAccessibilityEnabled ? Colors.green[700] : Colors.orange[700],
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isAccessibilityEnabled 
                              ? 'Floating Button Active!' 
                              : 'Floating Button Disabled',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isAccessibilityEnabled
                              ? 'Tap the floating button on any screen to capture'
                              : 'Enable to show floating capture button',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!_isAccessibilityEnabled) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showAccessibilitySetup,
                    icon: const Icon(Icons.settings),
                    label: const Text('Enable Floating Button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.help_outline, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    'How to Use',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildStep('1', 'Enable Floating Button', 'Turn on the accessibility service above'),
              _buildStep('2', 'Go to Any App', 'Chrome, Instagram, Messages, Email...'),
              _buildStep('3', 'Tap the Button', 'Tap the floating blue button to capture'),
              _buildStep('4', 'Select Region', 'Tap on the event text to focus analysis'),
              _buildStep('5', 'Add to Calendar', 'Calendar opens automatically with event filled in'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.flash_on, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Already have a screenshot? Tap the button below to analyze it directly.',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              if (_selectedImage != null)
                Container(
                  height: 150,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(_selectedImage!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

