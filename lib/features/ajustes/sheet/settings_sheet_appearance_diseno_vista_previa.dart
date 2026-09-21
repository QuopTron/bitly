// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_diseno_vista_previa.dart — PART de
// settings_sheet_new.dart: la vista previa del bloque "Diseño" de
// Apariencia.
//
// Dibuja ESQUELETOS con el diseño actual del usuario: mismo redondeo,
// misma separación (hueco entre cards + margen contra los bordes) y mismo
// borde que va a tener la app real, así no hay sorpresas al tocar un
// control.
// Se conecta con: settings_sheet_appearance_diseno.dart (misma library).
// Parte del flujo: Ajustes → Apariencia → Diseño.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Vista previa con esqueletos: el reproductor con su borde y una fila de
/// cards con el redondeo y la separación elegidos.
class _VistaPrevia extends StatelessWidget {
  final PreferenciasApariencia prefs;
  final StringsApariencia t;

  const _VistaPrevia({required this.prefs, required this.t});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final base = r.spacingXS;
    final sepX = base * prefs.espacioX;
    final sepY = base * prefs.espacioY;
    // El eje X también mueve el margen contra los bordes izq/der: la fila de
    // cards se mete o se corre según el mismo multiplicador.
    final margen = sepX;
    // Líneas del modo "unido" (tipo Spotify): aparecen solas al juntar.
    final opX = prefs.opacidadLineaX;
    final opY = prefs.opacidadLineaY;
    final linea = onBg.withValues(alpha: 0.35);
    final bloque = BoxDecoration(
      color: onBg.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(prefs.radioCards),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.vistaPreviaTitulo,
          style: TextStyle(
            fontSize: r.footerSize,
            fontWeight: FontWeight.w600,
            color: onBg.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: r.spacingS),
        // Reproductor en esqueleto, con el borde elegido.
        Container(
          height: 42,
          padding: EdgeInsets.symmetric(horizontal: sepX, vertical: 6),
          decoration: BoxDecoration(
            color: onBg.withValues(alpha: 0.04),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(
              color: onBg.withValues(
                alpha: AparienciaBarras.trazoBorde(context).$1,
              ),
              width: AparienciaBarras.trazoBorde(context).$2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: onBg.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(prefs.radioCards * 0.4),
                ),
              ),
              SizedBox(width: sepX),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(height: 7, width: 90, decoration: bloque),
                    SizedBox(height: sepY / 2 + 2),
                    Container(height: 5, width: 60, decoration: bloque),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: sepY + 4),
        // Fila de cards en esqueleto, con su margen contra los bordes.
        Padding(
          padding: EdgeInsets.symmetric(horizontal: margen),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0)
                    opX > 0.001
                        ? Container(
                          width: 0.6,
                          color: linea.withValues(alpha: opX),
                        )
                        : SizedBox(width: sepX),
                  Expanded(
                    child: Container(
                      decoration:
                          opY > 0.001
                              ? BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: linea.withValues(alpha: opY),
                                    width: 0.6,
                                  ),
                                ),
                              )
                              : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: Container(decoration: bloque),
                          ),
                          SizedBox(height: sepY / 2 + 2),
                          Container(height: 6, decoration: bloque),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: r.spacingXS),
        Text(
          t.vistaPreviaAyuda,
          style: TextStyle(
            fontSize: r.footerSize - 2,
            color: onBg.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}
