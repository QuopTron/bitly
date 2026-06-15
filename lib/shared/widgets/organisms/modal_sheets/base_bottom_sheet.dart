import 'package:flutter/material.dart';

class BaseBottomSheet extends StatelessWidget {
  final Widget child;
  final double? height;
  final bool showDragHandle;

  const BaseBottomSheet({
    super.key,
    required this.child,
    this.showDragHandle = true,
    this.height,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    double? height,
    bool showDragHandle = true,
    bool dismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: Colors.black54,
      enableDrag: dismissible,
      builder: (_) => BaseBottomSheet(
        height: height,
        showDragHandle: showDragHandle,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        color: Color(0xFF1A1A2E),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle) ...[
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: child,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
