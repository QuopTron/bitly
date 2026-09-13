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
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type toggle: Bug / Sugerencia
                  _ReportTypeToggle(
                    isBug: isBug,
                    glowColor: glow,
                    onBg: onBg,
                    r: r,
                    onChanged: (v) => setModalState(() => isBug = v),
                  ),
                  SizedBox(height: r.spacingM),
                  TextField(
                    controller: titleCtrl,
                    style: TextStyle(color: onBg),
                    decoration: InputDecoration(
                      labelText: loc.setup.reportTitle,
                      labelStyle: TextStyle(color: onBg.withValues(alpha: 0.5)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: onBg.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: glow),
                      ),
                    ),
                  ),
                  SizedBox(height: r.spacingS),
                  TextField(
                    controller: bodyCtrl,
                    maxLines: 4,
                    style: TextStyle(color: onBg),
                    decoration: InputDecoration(
                      hintText: loc.setup.reportBody,
                      hintStyle: TextStyle(color: onBg.withValues(alpha: 0.4)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: onBg.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: glow),
                      ),
                    ),
                  ),
                ],
              ),
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
