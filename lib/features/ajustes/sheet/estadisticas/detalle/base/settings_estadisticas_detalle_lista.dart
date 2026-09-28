// ─────────────────────────────────────────────────────────────
// settings_estadisticas_detalle_lista.dart — PART de settings_sheet
// _new.dart: la lista del detalle de estadísticas (cargando, vacía o
// las filas visibles). Cada fila vive en
// settings_estadisticas_detalle_fila.dart.
//
// Las carátulas llegan en un mapa id → ruta y se pintan cuando están:
// la lista aparece al instante y las portadas se acomodan después.
// Se conecta con: settings_sheet_new.dart (misma library) +
// settings_estadisticas_detalle.dart (la usa).
// Parte del flujo: Ajustes → Estadísticas → detalle.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Lista del detalle: cargando, vacía o las filas visibles.
class _ListaDetalle extends StatelessWidget {
  final bool cargando;
  final List<FilaEscucha> visibles;
  final Map<String, String> caratulas;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _ListaDetalle({
    required this.cargando,
    required this.visibles,
    required this.caratulas,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      // Esqueleto de las filas: puesto, carátula y dos líneas, con la misma
      // medida y el mismo radio que _FilaDetalle. Al llegar los datos nada se
      // corre de lugar (y se ve que lo que viene es una lista, no "algo").
      final lado = r.subtitleSize * 1.9;
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(r.spacingM, 0, r.spacingM, r.spacingS),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        separatorBuilder: (_, _) => SizedBox(height: r.spacingXS * 0.8),
        itemBuilder:
            (_, _) => Container(
              padding: EdgeInsets.symmetric(
                horizontal: r.spacingS,
                vertical: r.spacingXS * 1.2,
              ),
              decoration: BoxDecoration(
                color: onBg.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: r.footerSize * 1.5,
                    child: Center(
                      child: EsqueletoCarga(
                        ancho: r.footerSize * 0.6,
                        alto: r.footerSize * 0.6,
                        radioBorde: 4,
                      ),
                    ),
                  ),
                  EsqueletoCarga(ancho: lado, alto: lado, radioBorde: 10),
                  SizedBox(width: r.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EsqueletoCarga(alto: r.footerSize, radioBorde: 6),
                        SizedBox(height: r.spacingXS),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 0.6,
                          child: EsqueletoCarga(
                            alto: r.footerSize - 2,
                            radioBorde: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      );
    }
    if (visibles.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(r.spacingL),
          child: Text(
            AppLocalizations.of(context).estadisticas.detalleVacio,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.footerSize,
              color: onBg.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(r.spacingM, 0, r.spacingM, r.spacingS),
      itemCount: visibles.length,
      separatorBuilder: (_, _) => SizedBox(height: r.spacingXS * 0.8),
      itemBuilder:
          (context, i) => _FilaDetalle(
            puesto: i + 1,
            fila: visibles[i],
            caratula: caratulas[visibles[i].id],
            glowColor: glowColor,
            onBg: onBg,
            r: r,
          ),
    );
  }
}
