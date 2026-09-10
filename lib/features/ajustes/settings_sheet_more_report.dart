part of 'settings_sheet_new.dart';

/// Card de reporte de bug / sugerencia dentro del tab "Más".
/// Al tocarla abre un diálogo con formulario que crea un issue de GitHub
/// en el repo del desarrollador usando el token configurado.
class _ReportCardWidget extends StatelessWidget {
  final Color glowColor;

  const _ReportCardWidget({required this.glowColor});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.bug_report_rounded,
              color: glowColor,
              size: r.subtitleSize,
            ),
            SizedBox(width: r.spacingS),
            Text(
              AppLocalizations.of(context).setup.reportBug,
              style: TextStyle(
                fontSize: r.subtitleSize,
                fontWeight: FontWeight.w700,
                color: onBg,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          AppLocalizations.of(context).setup.reportDesc,
          style: TextStyle(
            fontSize: r.footerSize - 1,
            color: onBg.withValues(alpha: 0.5),
            height: 1.3,
          ),
        ),
        SizedBox(height: r.spacingS),
        GestureDetector(
          onTap: () => showReportDialog(context, glowColor),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: r.spacingM,
              vertical: r.spacingM,
            ),
            decoration: BoxDecoration(
              color: onBg.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: glowColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.edit_rounded,
                  size: r.subtitleSize + 2,
                  color: glowColor,
                ),
                SizedBox(width: r.spacingS),
                Text(
                  AppLocalizations.of(context).setup.reportBug,
                  style: TextStyle(
                    fontSize: r.subtitleSize,
                    fontWeight: FontWeight.w600,
                    color: onBg.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
