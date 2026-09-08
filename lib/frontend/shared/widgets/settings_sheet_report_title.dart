part of 'settings_sheet_new.dart';

/// Título del diálogo de reporte: ícono bug/idea según el tipo y el texto
/// localizado de "reportar bug".
class _ReportDialogTitle extends StatelessWidget {
  final bool isBug;
  final AppLocalizations loc;
  final Color onBg;
  final Responsive r;

  const _ReportDialogTitle({
    required this.isBug,
    required this.loc,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isBug ? Icons.bug_report_rounded : Icons.lightbulb_rounded,
          color: isBug ? Colors.redAccent : Colors.amber,
          size: 22,
        ),
        SizedBox(width: r.spacingS),
        Text(
          loc.setup.reportBug,
          style: TextStyle(
            color: onBg,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
