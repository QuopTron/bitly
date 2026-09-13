// Parte del split de settings_sheet_new.dart — helpers de la fila de
// configuración de calidad de descarga (funciones top-level usadas por
// _DownloadQualityCard). Extraídas del archivo original (ver git log).
part of 'settings_sheet_new.dart';

Widget _downloadHeaderRow(
  IconData icon,
  String label,
  Color onBg,
  Responsive r,
  Color glowColor,
) {
  return Row(
    children: [
      Icon(icon, size: r.subtitleSize, color: glowColor),
      SizedBox(width: r.spacingS),
      Text(
        label,
        style: TextStyle(
          fontSize: r.subtitleSize,
          fontWeight: FontWeight.w700,
          color: onBg,
        ),
      ),
    ],
  );
}

Widget _downloadSwitchRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
  required Color glowColor,
  required Color onBg,
}) {
  final r = Responsive(context);
  return Row(
    children: [
      Icon(icon, color: onBg.withValues(alpha: 0.55), size: r.footerSize + 2),
      SizedBox(width: r.spacingS),
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: r.subtitleSize - 1,
            color: onBg,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: glowColor.withValues(alpha: 0.3),
        activeThumbColor: glowColor,
      ),
    ],
  );
}

/// A clean labeled dropdown: icon + hint text + arrow, opening a themed
/// bottom-sheet picker so every option is readable and the chosen one
/// glows.
