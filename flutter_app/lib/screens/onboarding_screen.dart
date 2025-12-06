import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import '../services/accessibility_service.dart';

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
      icon: Icons.calendar_month_rounded,
      title: 'Welcome to TapCal',
      description: 'Instantly create calendar events from any screen on your phone.',
      color: const Color(0xFF6366F1),
    ),
    OnboardingPage(
      icon: Icons.touch_app_rounded,
      title: 'One Tap Capture',
      description: 'Tap the floating button to capture any screen with event information.',
      color: const Color(0xFF8B5CF6),
    ),
    OnboardingPage(
      icon: Icons.crop_rounded,
      title: 'Smart Selection',
      description: 'Tap on the event text to focus AI analysis on that area.',
      color: const Color(0xFF10B981),
    ),
    OnboardingPage(
      icon: Icons.shield_rounded,
      title: 'Privacy First',
      description: 'Screenshots are deleted immediately after analysis. Nothing is stored on servers.',
      color: const Color(0xFF1E293B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    // Start initial animations
    Future.delayed(const Duration(milliseconds: 200), () {
      _iconController.forward();
      Future.delayed(const Duration(milliseconds: 300), () {
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
    
    // Restart animations for new page
    _iconController.reset();
    _textController.reset();
    
    Future.delayed(const Duration(milliseconds: 100), () {
      _iconController.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
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
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                )),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
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
                      color: Colors.grey[600],
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
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildPageIndicator(index),
                ),
              ),
            ),
            
            // Bottom buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: _currentPage == _pages.length - 1
                  ? _buildGetStartedButton()
                  : _buildNextButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    final isActive = _currentPage == index;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 28 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? _pages[_currentPage].color
            : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: _pages[_currentPage].color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon container
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _iconController,
              curve: Curves.elasticOut,
            ),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: page.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: page.color.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated rings
                  _AnimatedRing(color: page.color, size: 120, delay: 0),
                  _AnimatedRing(color: page.color, size: 100, delay: 100),
                  // Main icon
                  Icon(
                    page.icon,
                    size: 60,
                    color: page.color,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 56),
          
          // Animated title
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _textController,
              curve: Curves.easeOut,
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _textController,
                curve: Curves.easeOut,
              )),
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
          
          // Animated description
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _textController,
              curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _textController,
                curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
              )),
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
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1.0),
      duration: const Duration(milliseconds: 200),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 400),
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
                elevation: 4,
                shadowColor: _pages[_currentPage].color.withOpacity(0.4),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Next',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGetStartedButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await _completeOnboarding();
                AccessibilityService.openSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                shadowColor: const Color(0xFF10B981).withOpacity(0.4),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rocket_launch_rounded, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Get Started',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedRing extends StatefulWidget {
  final Color color;
  final double size;
  final int delay;

  const _AnimatedRing({
    required this.color,
    required this.size,
    required this.delay,
  });

  @override
  State<_AnimatedRing> createState() => _AnimatedRingState();
}

class _AnimatedRingState extends State<_AnimatedRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _animation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size * _animation.value,
          height: widget.size * _animation.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withOpacity(0.2 * _animation.value),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
