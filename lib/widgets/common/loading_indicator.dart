import 'package:flutter/material.dart';
import 'package:bitly/constants/layout_constants.dart';

class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final double strokeWidth;

  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 36,
    this.strokeWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: strokeWidth,
              color: colorScheme.primary,
            ),
          ),
          if (message != null) ...[
            LayoutConstants.gapH12,
            Text(
              message!,
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
