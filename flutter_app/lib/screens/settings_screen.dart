import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event_history.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _apiUrl = 'https://tap-cal.vercel.app';
  bool _hapticFeedback = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiUrl = prefs.getString('api_url') ?? 'https://tap-cal.vercel.app';
      _hapticFeedback = prefs.getBool('haptic_feedback') ?? true;
    });
  }

  Future<void> _saveApiUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_url', url);
    setState(() => _apiUrl = url);
  }

  Future<void> _toggleHaptic(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('haptic_feedback', value);
    setState(() => _hapticFeedback = value);
  }

  static const _nativeChannel = MethodChannel('com.tapcal.tapcal_app/native');
  
  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('This will delete all detected events from history. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[400]),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Clear native SharedPreferences (where scan history is stored)
      try {
        await _nativeChannel.invokeMethod('clearHistory');
      } catch (e) {
        print('[Settings] Error clearing native history: $e');
      }
      
      // Also clear Flutter SharedPreferences (legacy)
      await EventHistoryService.clearHistory();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('History cleared')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // API Configuration
          _buildSection(
            title: 'API Configuration',
            icon: Icons.cloud_outlined,
            children: [
              _buildSettingTile(
                title: 'API Endpoint',
                subtitle: _apiUrl,
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _showApiUrlDialog(),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Preferences
          _buildSection(
            title: 'Preferences',
            icon: Icons.tune_outlined,
            children: [
              SwitchListTile(
                title: const Text('Haptic Feedback'),
                subtitle: const Text('Vibrate when capturing'),
                value: _hapticFeedback,
                onChanged: _toggleHaptic,
                activeColor: const Color(0xFF6366F1),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Data
          _buildSection(
            title: 'Data',
            icon: Icons.storage_outlined,
            children: [
              ListTile(
                title: const Text('Clear History'),
                subtitle: const Text('Delete all detected events'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _clearHistory,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // About
          _buildSection(
            title: 'About',
            icon: Icons.info_outline,
            children: [
              const ListTile(
                title: Text('Version'),
                subtitle: Text('1.0.0'),
              ),
              const ListTile(
                title: Text('Developer'),
                subtitle: Text('SnapCal Team'),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Privacy notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.grey[600], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Screenshots are processed securely and deleted immediately after analysis.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing,
    );
  }

  void _showApiUrlDialog() {
    final controller = TextEditingController(text: _apiUrl);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Endpoint'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://your-api.vercel.app',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveApiUrl(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}


