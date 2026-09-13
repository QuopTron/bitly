// Parte del split de settings_sheet_new.dart — dropdown de calidad y labels
// de calidad (funciones top-level usadas por _DownloadQualityCard).
// Extraídas del archivo original (ver git log).
part of 'settings_sheet_new.dart';

Widget _downloadDropdownRow(
  BuildContext context, {
  required IconData icon,
  required String hint,
  required List<String> options,
  required String Function(String) labelFor,
  required String current,
  required ValueChanged<String> onChanged,
  required Color glowColor,
  required Color onBg,
}) {
  final r = Responsive(context);
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap:
        () => _showPicker(
          context: context,
          title: hint,
          options: options,
          labelFor: labelFor,
          current: current,
          onChanged: onChanged,
          glowColor: glowColor,
          onBg: onBg,
          r: r,
        ),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: r.spacingM,
        vertical: r.spacingS,
      ),
      decoration: BoxDecoration(
        color: onBg.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: glowColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: r.footerSize + 2, color: glowColor),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Text(
              hint,
              style: TextStyle(
                fontSize: r.subtitleSize - 1,
                color: onBg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: onBg.withValues(alpha: 0.4),
            size: r.footerSize + 4,
          ),
        ],
      ),
    ),
  );
}

/// Bottom-sheet option picker: each row is a big tappable surface with a
/// check on the selected one — much easier to read than pills.
