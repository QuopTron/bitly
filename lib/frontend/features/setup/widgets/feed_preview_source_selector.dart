import 'package:flutter/material.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/source_accordion.dart';

class FeedPreviewSourceSelector extends StatelessWidget {
  final String selectedSource;
  final Map<String, String> availableSources;
  final IconData Function(String src) sourceIcon;
  final ValueChanged<String> onChanged;
  final Color onBg;
  final Color glowColor;

  const FeedPreviewSourceSelector({
    super.key,
    required this.selectedSource,
    required this.availableSources,
    required this.sourceIcon,
    required this.onChanged,
    required this.onBg,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    if (availableSources.isEmpty) return const SizedBox.shrink();
    final r = Responsive(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(r.spacingS, r.spacingS, r.spacingS, 0),
      child: SourceAccordion(
        sources: availableSources,
        selectedSource: selectedSource,
        onBg: onBg,
        glowColor: glowColor,
        onChanged: onChanged,
      ),
    );
  }
}
