// ─────────────────────────────────────────────────────────────
// settings_sheet_soulseek_sheet_visual.dart — PART de settings_sheet
// _new.dart: armazón visual de la hoja de Soulseek (fondo, handle,
// encabezado y contenido). El estado y la lógica viven en
// settings_sheet_soulseek_sheet.dart.
// Se conecta con: settings_sheet_new.dart (misma library) +
// settings_sheet_soulseek_sheet (lo monta).
// Parte del flujo: Ajustes → Más (visual de la hoja Soulseek).
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Armazón visual de la hoja de Soulseek. Recibe el estado ya resuelto.
class _SoulseekSheetVisual extends StatelessWidget {
  final bool datosListos;
  final bool cargando;
  final bool conectada;
  final bool propuestaDeLaApp;
  final bool revelada;
  final String password;
  final String? mensaje;
  final TextEditingController nombreCtrl;
  final Color glow;
  final Color onBg;
  final Color bg;
  final Responsive r;
  final VoidCallback onSiguiente;
  final VoidCallback onToggleRevelada;

  const _SoulseekSheetVisual({
    required this.datosListos,
    required this.cargando,
    required this.conectada,
    required this.propuestaDeLaApp,
    required this.revelada,
    required this.password,
    required this.mensaje,
    required this.nombreCtrl,
    required this.glow,
    required this.onBg,
    required this.bg,
    required this.r,
    required this.onSiguiente,
    required this.onToggleRevelada,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.only(top: r.spacingXL * 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        // Deja lugar al teclado: sin esto el campo queda tapado al escribir.
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: r.spacingM),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: onBg.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: r.spacingM),
              _SoulseekSheetHeader(
                glow: glow,
                conectada: conectada,
                onBg: onBg,
                r: r,
              ),
              SizedBox(height: r.spacingM),
              if (!datosListos)
                // Esqueleto del formulario: el rótulo, la propuesta y los dos
                // campos, con la forma y el alto que van a tener de verdad.
                // Una ruedita no anticipa nada y el formulario "aparecía" de
                // golpe.
                Padding(
                  padding: EdgeInsets.symmetric(vertical: r.spacingS),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EsqueletoCarga(
                        ancho: r.spacingL * 3,
                        alto: r.footerSize,
                        radioBorde: 6,
                      ),
                      SizedBox(height: r.spacingM),
                      EsqueletoCarga(
                        alto: r.spacingL * 2.2,
                        radioBorde: 12,
                      ),
                      SizedBox(height: r.spacingS),
                      EsqueletoCarga(
                        alto: r.spacingL * 2.2,
                        radioBorde: 12,
                      ),
                      SizedBox(height: r.spacingM),
                      EsqueletoCarga(
                        alto: r.spacingL * 1.6,
                        radioBorde: 12,
                      ),
                    ],
                  ),
                )
              else
                _SoulseekForm(
                  nombreCtrl: nombreCtrl,
                  cargando: cargando,
                  conectada: conectada,
                  propuestaDeLaApp: propuestaDeLaApp,
                  revelada: revelada,
                  password: password,
                  mensaje: mensaje,
                  glow: glow,
                  onBg: onBg,
                  r: r,
                  onSiguiente: onSiguiente,
                  onToggleRevelada: onToggleRevelada,
                ),
              SizedBox(height: r.bottomPadding + insetInferiorSistema(context)),
            ],
          ),
        ),
      ),
    );
  }
}
