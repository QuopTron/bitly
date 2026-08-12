import 'package:flutter/material.dart';
import '../../../shared/utils/responsive.dart';

class FeedPreviewHeader extends StatelessWidget {
  final Color onBg;
  final String title;
  final String description;

  const FeedPreviewHeader({
    super.key,
    required this.onBg,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(height: r.spacingS),
      Container(
        padding: EdgeInsets.all(r.spacingS),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onBg.withValues(alpha: 0.04),
          border: Border.all(color: onBg.withValues(alpha: 0.08), width: 0.8),
        ),
        child: Icon(Icons.home_outlined, size: r.titleSize * 1.1, color: onBg.withValues(alpha: 0.55)),
      ),
      SizedBox(height: r.spacingS),
      Text(title,
        style: TextStyle(fontSize: r.titleSize, fontWeight: FontWeight.bold, color: onBg, letterSpacing: 1)),
      SizedBox(height: 2),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
        child: Text(description,
          style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.5)),
          textAlign: TextAlign.center),
      ),
    ]);
  }
}


