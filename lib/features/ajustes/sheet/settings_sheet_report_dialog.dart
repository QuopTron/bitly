// ─────────────────────────────────────────────────────────────
// settings_sheet_report_dialog.dart — PART de settings_sheet_new.dart: diálogo para escribir y enviar
// un reporte de bug o sugerencia.
// Se conecta con: settings_sheet_new.dart (misma library).
// Parte del flujo: Ajustes → Más (diálogo de reporte).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Abre el diálogo de reporte bug / sugerencia. Al enviar crea un issue de
/// GitHub en el repo del desarrollador con el token configurado.
Future<void> showReportDialog(BuildContext context, Color glowColor) async {
  final loc = AppLocalizations.of(context);
  final r = Responsive(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final onBg = ColoresApp.enSuperficie(isDark);
  final bg = ColoresApp.superficie(isDark);
  final glow = glowColor;

  var isBug = true;
  final titleCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();
  var sending = false;
  var sent = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: _ReportDialogTitle(isBug: isBug, loc: loc, onBg: onBg, r: r),
            content: _contenidoDialogoReporte(
              isBug: isBug,
              glow: glow,
              onBg: onBg,
              r: r,
              loc: loc,
              titleCtrl: titleCtrl,
              bodyCtrl: bodyCtrl,
              setModalState: setModalState,
              onBugCambiado: (v) => setModalState(() => isBug = v),
            ),
            actions: [
              TextButton(
                onPressed: sending ? null : () => Navigator.pop(ctx),
                child: Text(
                  loc.setup.cancel,
                  style: TextStyle(color: onBg.withValues(alpha: 0.6)),
                ),
              ),
              FilledButton(
                onPressed:
                    sending
                        ? null
                        : () async {
                          setModalState(() => sending = true);
                          final ok = await submitReport(
                            context: context,
                            isBug: isBug,
                            title: titleCtrl.text.trim(),
                            body: bodyCtrl.text.trim(),
                          );
                          sent = ok;
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                style: FilledButton.styleFrom(
                  backgroundColor: isBug ? Colors.redAccent : glow,
                ),
                child:
                    sending
                        ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Text(
                          loc.setup.reportSend,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
              ),
            ],
          );
        },
      );
    },
  );

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(sent ? loc.setup.reportSent : loc.setup.reportFailed),
        backgroundColor: sent ? Colors.green.shade700 : Colors.red.shade700,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
