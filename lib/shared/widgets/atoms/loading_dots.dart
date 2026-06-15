import 'package:flutter/material.dart';

class LoadingDots extends StatefulWidget {
  final Color color;
  final double dotSize;
  final Duration duration;

  const LoadingDots({
    super.key,
    this.color = Colors.green,
    this.dotSize = 8.0,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final delay = index * 0.15;
            final value = (_controller.value - delay).clamp(0.0, 1.0);
            final scale = 0.5 + (value * 0.5);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.dotSize * 0.3),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
