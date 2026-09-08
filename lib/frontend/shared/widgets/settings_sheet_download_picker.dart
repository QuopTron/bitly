part of 'settings_sheet_new.dart';

Future<void> _showPicker({
  required BuildContext context,
  required String title,
  required List<String> options,
  required String Function(String) labelFor,
  required String current,
  required ValueChanged<String> onChanged,
  required Color glowColor,
  required Color onBg,
  required Responsive r,
}) async {
  final selected = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
      final sheetOnBg = AppColors.onSurface(isDark);
      final sheetBg = AppColors.surface(isDark);
      return Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(sheetCtx).bottom + r.spacingM,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: r.spacingM),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetOnBg.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: r.spacingM),
              Text(
                title,
                style: TextStyle(
                  fontSize: r.subtitleSize,
                  fontWeight: FontWeight.w700,
                  color: sheetOnBg,
                ),
              ),
              SizedBox(height: r.spacingS),
              ...options.map((q) {
                final sel = q == current;
                return InkWell(
                  onTap: () => Navigator.pop(sheetCtx, q),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.spacingL,
                      vertical: r.spacingM,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            labelFor(q),
                            style: TextStyle(
                              fontSize: r.subtitleSize,
                              fontWeight:
                                  sel ? FontWeight.w700 : FontWeight.w500,
                              color:
                                  sel
                                      ? glowColor
                                      : sheetOnBg.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        if (sel)
                          Icon(
                            Icons.check_circle_rounded,
                            color: glowColor,
                            size: r.footerSize + 4,
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    },
  );
  if (selected != null && selected != current) onChanged(selected);
}
