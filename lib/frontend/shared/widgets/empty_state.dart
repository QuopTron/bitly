import 'package:flutter/material.dart';

/// Animated empty state with floating music notes. Used for search results,
/// liked songs, downloaded tracks, etc.
class AnimatedEmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? accentColor;

  const AnimatedEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accentColor,
  });

  @override
  State<AnimatedEmptyState> createState() => _AnimatedEmptyStateState();
}

class _AnimatedEmptyStateState extends State<AnimatedEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor ??
        (isDark ? const Color(0xFF1ED760) : const Color(0xFF1DB954));
    final fg = isDark ? Colors.white : Colors.black;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Floating icon with glow
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final t = _ctrl.value;
                return Transform.translate(
                  offset: Offset(0, -4 + t * 8),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.15 + t * 0.1),
                          blurRadius: 30 + t * 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      size: 48,
                      color: accent.withValues(alpha: 0.6 + t * 0.2),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: fg.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: fg.withValues(alpha: 0.4),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
