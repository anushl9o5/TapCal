import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  late AnimationController _iconController;
  late AnimationController _textController;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      emoji: '📸',
      title: 'Welcome to SnapCal',
      description: 'Turn any screen into calendar events with one tap.',
      color: const Color(0xFF6366F1),
    ),
    OnboardingPage(
      emoji: '🔔',
      title: 'Notification Capture',
      description: 'Swipe down and tap the SnapCal notification to capture whatever\'s on screen.',
      color: const Color(0xFF8B5CF6),
    ),
    OnboardingPage(
      emoji: '🤖',
      title: 'AI Finds Events',
      description: 'Our AI scans the screenshot and extracts all event details automatically.',
      color: const Color(0xFF10B981),
    ),
    OnboardingPage(
      emoji: '🔒',
      title: 'Private & Secure',
      description: 'Screenshots are deleted immediately. Your data never leaves your device.',
      color: const Color(0xFF1E293B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    Future.delayed(const Duration(milliseconds: 200), () {
      _iconController.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        _textController.forward();
      });
    });
  }

  @override
  void dispose() {
    _iconController.dispose();
    _textController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    
    _iconController.reset();
    _textController.reset();
    
    Future.delayed(const Duration(milliseconds: 50), () {
      _iconController.forward();
      Future.delayed(const Duration(milliseconds: 150), () {
        _textController.forward();
      });
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _pages[_currentPage].color.withOpacity(0.1),
              const Color(0xFFF8FAFC),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) => _buildPage(_pages[index]),
                ),
              ),
              
              // Page indicators
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => _buildPageIndicator(index),
                  ),
                ),
              ),
              
              // Bottom button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: _currentPage == _pages.length - 1
                    ? _buildGetStartedButton()
                    : _buildNextButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    final isActive = _currentPage == index;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? _pages[_currentPage].color : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji with animated container
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _iconController,
              curve: Curves.elasticOut,
            ),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: page.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Center(
                child: Text(
                  page.emoji,
                  style: const TextStyle(fontSize: 56),
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          
          // Title
          FadeTransition(
            opacity: _textController,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.2),
                end: Offset.zero,
              ).animate(_textController),
              child: Text(
                page.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Description
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _textController,
              curve: const Interval(0.3, 1.0),
            ),
            child: Text(
              page.description,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _pages[_currentPage].color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Next',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildGetStartedButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _completeOnboarding,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Get Started',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String emoji;
  final String title;
  final String description;
  final Color color;

  OnboardingPage({
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
  });
}
