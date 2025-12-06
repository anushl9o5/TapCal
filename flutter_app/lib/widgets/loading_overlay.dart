import 'package:flutter/material.dart';

class LoadingOverlay extends StatefulWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isLoading) {
      _fadeController.forward();
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _fadeController.forward();
      _pulseController.repeat(reverse: true);
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _fadeController.reverse();
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.isLoading)
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              color: const Color(0xFF1E293B).withOpacity(0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated scanning circle
                    _buildScanningIndicator(),
                    const SizedBox(height: 32),
                    // Animated text
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: Text(
                        widget.message ?? 'Looking for calendar events...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'AI analyzing your screen',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScanningIndicator() {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer rotating ring
          _RotatingRing(
            size: 80,
            strokeWidth: 3,
            color: const Color(0xFF6366F1).withOpacity(0.3),
          ),
          // Middle rotating ring (opposite direction)
          _RotatingRing(
            size: 60,
            strokeWidth: 2,
            color: const Color(0xFF8B5CF6).withOpacity(0.5),
            reverse: true,
            duration: const Duration(milliseconds: 1500),
          ),
          // Center pulsing dot
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 20 + (4 * _pulseAnimation.value),
                height: 20 + (4 * _pulseAnimation.value),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                      blurRadius: 12 * _pulseAnimation.value,
                      spreadRadius: 2 * _pulseAnimation.value,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RotatingRing extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color color;
  final bool reverse;
  final Duration duration;

  const _RotatingRing({
    required this.size,
    required this.strokeWidth,
    required this.color,
    this.reverse = false,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<_RotatingRing> createState() => _RotatingRingState();
}

class _RotatingRingState extends State<_RotatingRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: widget.reverse
          ? Tween(begin: 1.0, end: 0.0).animate(_controller)
          : _controller,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _ArcPainter(
            color: widget.color,
            strokeWidth: widget.strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _ArcPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    // Draw arc (270 degrees, leaving a gap)
    canvas.drawArc(rect, -0.5, 4.2, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
