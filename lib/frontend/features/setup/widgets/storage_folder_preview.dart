import 'package:flutter/material.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/glass_container.dart';

class StorageFolderPreview extends StatelessWidget {
  final bool hasPath;
  final bool usingDefault;
  final bool picking;
  final String displayPath;
  final String selectedLabel;
  final String noFolderLabel;
  final Color onBg;
  final Color glowColor;

  const StorageFolderPreview({
    super.key,
    required this.hasPath,
    required this.usingDefault,
    required this.picking,
    required this.displayPath,
    required this.selectedLabel,
    required this.noFolderLabel,
    required this.onBg,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingL),
      child: GlassContainer(
        borderRadius: 14,
        borderColor: hasPath ? glowColor.withValues(alpha: 0.3) : onBg.withValues(alpha: 0.08),
        bgColor: hasPath ? glowColor.withValues(alpha: 0.04) : Colors.transparent,
        padding: EdgeInsets.all(r.spacingM),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.all(r.spacingS),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasPath ? glowColor.withValues(alpha: 0.15) : onBg.withValues(alpha: 0.04),
            ),
            child: Icon(
              hasPath ? Icons.folder : Icons.folder_open,
              size: r.titleSize,
              color: hasPath ? glowColor : onBg.withValues(alpha: 0.3),
            ),
          ),
          SizedBox(width: r.spacingM),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hasPath ? selectedLabel : noFolderLabel,
                style: TextStyle(fontSize: r.footerSize,
                  fontWeight: FontWeight.w600,
                  color: hasPath ? glowColor : onBg.withValues(alpha: 0.3))),
              SizedBox(height: 2),
              Text(displayPath,
                style: TextStyle(fontSize: r.footerSize - 2,
                  color: onBg.withValues(alpha: 0.4)),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (picking)
            SizedBox(width: r.footerSize, height: r.footerSize,
              child: CircularProgressIndicator(strokeWidth: 2, color: glowColor)),
        ]),
      ),
    );
  }
}


