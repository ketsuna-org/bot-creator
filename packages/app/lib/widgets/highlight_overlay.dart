import 'package:flutter/material.dart';

/// A widget that highlights a target widget on screen with a spotlight/overlay effect.
/// Shows text description, an arrow pointing to the target, and typical tutorial UI.
class HighlightOverlay extends StatefulWidget {
  final Widget child;

  /// The widget key to highlight (must be assigned to the widget you want to highlight)
  final GlobalKey targetKey;

  /// Text to display above/below the highlight
  final String title;

  /// Detailed description text
  final String description;

  /// Action buttons (e.g., "Next", "Skip")
  final List<Widget> actions;

  /// Called when overlay is dismissed/closed
  final VoidCallback? onDismiss;

  /// Optional padding around highlighted widget to expand the spotlight
  final double highlightPadding;

  /// Color of the overlay background (semi-transparent)
  final Color overlayColor;

  /// Opacity of overlay (0.0 to 1.0)
  final double overlayOpacity;

  const HighlightOverlay({
    super.key,
    required this.child,
    required this.targetKey,
    required this.title,
    required this.description,
    required this.actions,
    this.onDismiss,
    this.highlightPadding = 8.0,
    this.overlayColor = Colors.black,
    this.overlayOpacity = 0.7,
  });

  @override
  State<HighlightOverlay> createState() => _HighlightOverlayState();
}

class _HighlightOverlayState extends State<HighlightOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Rect? _targetRect;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    // Calculate target position after frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTargetRect();
      _animationController.forward();
    });
  }

  void _updateTargetRect() {
    final context = widget.targetKey.currentContext;
    if (context == null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    setState(() {
      _targetRect = Rect.fromLTWH(
        offset.dx - widget.highlightPadding,
        offset.dy - widget.highlightPadding,
        renderBox.size.width + (widget.highlightPadding * 2),
        renderBox.size.height + (widget.highlightPadding * 2),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_targetRect != null)
          FadeTransition(
            opacity: _fadeAnimation,
            child: CustomPaint(
              painter: _HighlightPainter(
                targetRect: _targetRect!,
                overlayColor: widget.overlayColor,
                overlayOpacity: widget.overlayOpacity,
              ),
              size: Size.infinite,
            ),
          ),
        if (_targetRect != null)
          FadeTransition(
            opacity: _fadeAnimation,
            child: _TutorialCard(
              targetRect: _targetRect!,
              title: widget.title,
              description: widget.description,
              actions: widget.actions,
              screenSize: MediaQuery.of(context).size,
            ),
          ),
      ],
    );
  }
}

/// Custom painter that draws the semi-transparent overlay with a highlighted cutout
class _HighlightPainter extends CustomPainter {
  final Rect targetRect;
  final Color overlayColor;
  final double overlayOpacity;

  _HighlightPainter({
    required this.targetRect,
    required this.overlayColor,
    required this.overlayOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw semi-transparent overlay covering entire screen
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = overlayColor.withValues(alpha: overlayOpacity)
        ..style = PaintingStyle.fill,
    );

    // Clear the highlight area (cut out the spotlight)
    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect, const Radius.circular(8)),
      Paint()
        ..blendMode = BlendMode.clear
        ..color = Colors.transparent,
    );

    // Draw border around highlighted widget
    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect, const Radius.circular(8)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.overlayOpacity != overlayOpacity;
  }
}

/// Card that displays the tutorial text + actions
/// Positioned above or below the highlighted widget intelligently
class _TutorialCard extends StatelessWidget {
  final Rect targetRect;
  final String title;
  final String description;
  final List<Widget> actions;
  final Size screenSize;

  const _TutorialCard({
    required this.targetRect,
    required this.title,
    required this.description,
    required this.actions,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    // Determine if card should be above or below the target
    final spaceAbove = targetRect.top;
    final spaceBelow = screenSize.height - targetRect.bottom;

    final isAbove = spaceAbove > spaceBelow && spaceAbove > 200;

    final cardWidth = screenSize.width * 0.85;
    final maxCardWidth = 320.0;
    final finalWidth = cardWidth > maxCardWidth ? maxCardWidth : cardWidth;

    double cardX;
    if (targetRect.center.dx + (finalWidth / 2) > screenSize.width) {
      cardX = screenSize.width - finalWidth - 16;
    } else if (targetRect.center.dx - (finalWidth / 2) < 0) {
      cardX = 16;
    } else {
      cardX = targetRect.center.dx - (finalWidth / 2);
    }

    double cardY;
    if (isAbove) {
      cardY = targetRect.top - 170;
    } else {
      cardY = targetRect.bottom + 16;
    }

    return Positioned(
      left: cardX,
      top: cardY,
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: finalWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Arrow pointing to target
              if (isAbove)
                Align(
                  alignment: Alignment.centerRight,
                  child: Transform.rotate(
                    angle: 0.785, // 45 degrees
                    child: Container(
                      width: 12,
                      height: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              // Card content
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions,
                      ),
                    ],
                  ),
                ),
              ),
              // Arrow pointing to target (if below)
              if (!isAbove)
                Align(
                  alignment: Alignment.centerRight,
                  child: Transform.rotate(
                    angle: -2.356, // 225 degrees
                    child: Container(
                      width: 12,
                      height: 12,
                      color: Colors.white,
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
