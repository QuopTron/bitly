// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_barras_previa_barra.dart — PART de
// settings_sheet_new.dart: la BARRA DE EJEMPLO de la vista previa.
//
// Es la forma que se ve en la previa del espacio Barras: su redondeo de
// arriba y su contorno son los REALES de esa barra, y adentro lleva un
// contenido mínimo para que se entienda cuál es (puntitos parejos = navbar;
// carátula con dos líneas = miniplayer).
//
// Va aparte de _barras_previa para que cada archivo haga una sola cosa: uno
// alterna entre las dos barras, este las dibuja.
//
// Se conecta con: settings_sheet_appearance_barras_previa.dart (la usa).
// Parte del flujo: Ajustes → Apariencia → Barras.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Una barra de ejemplo: su forma de arriba, su contorno y sus "contenidos".
class _BarraEjemplo extends StatelessWidget {
  final bool navbar;
  final PreferenciasApariencia prefs;
  final Responsive r;
  final Color onBg;
  final Color glowColor;

  /// ¿Es la barra que se está editando? Lleva el anillo de acento.
  final bool seleccionada;

  const _BarraEjemplo({
    super.key,
    required this.navbar,
    required this.prefs,
    required this.r,
    required this.onBg,
    required this.glowColor,
    required this.seleccionada,
  });

  @override
  Widget build(BuildContext context) {
    final trazo = AparienciaBarras.trazoBorde(context);
    // Adorno real de esta barra (esquinas u olas) y su calcomanía.
    final adorno = AparienciaDisenos.adornoDe(context, navbar: navbar);
    final esOlas = adorno == AdornoBarra.olas;
    final radio = navbar ? prefs.radioNavbar : prefs.radioMiniplayer;
    final forma = BorderRadius.vertical(top: Radius.circular(radio));
    final colorBorde =
        seleccionada ? glowColor : onBg.withValues(alpha: trazo.$1);
    final alto = navbar ? r.spacingL * 2.4 : r.spacingL * 1.8;
    return BarraAdornada(
      adorno: adorno,
      olas: AparienciaDisenos.olasDe(context, navbar: navbar),
      radioArriba: radio,
      colorBorde: colorBorde,
      sticker: AparienciaDisenos.stickerDe(context, navbar: navbar),
      colorSticker: seleccionada ? glowColor : onBg.withValues(alpha: 0.75),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: navbar ? double.infinity : r.width * 0.74,
        height: alto,
        padding: EdgeInsets.symmetric(horizontal: r.spacingS),
        decoration: BoxDecoration(
          color: onBg.withValues(alpha: 0.06),
          borderRadius: esOlas ? BorderRadius.zero : forma,
          border:
              esOlas
                  ? null
                  : Border.all(
                    color: colorBorde,
                    width: seleccionada ? 1.6 : trazo.$2,
                  ),
        ),
        child: navbar ? _puntos() : _miniplayer(),
      ),
    );
  }

  /// Los íconos del navbar, como puntitos parejos.
  Widget _puntos() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      for (var i = 0; i < 5; i++)
        Container(
          width: r.spacingS,
          height: r.spacingS,
          decoration: BoxDecoration(
            color: onBg.withValues(alpha: i == 0 ? 0.45 : 0.2),
            shape: BoxShape.circle,
          ),
        ),
    ],
  );

  /// El miniplayer: su carátula y las dos líneas de título/subtítulo.
  Widget _miniplayer() => Row(
    children: [
      Container(
        width: r.spacingL,
        height: r.spacingL,
        decoration: BoxDecoration(
          color: onBg.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      SizedBox(width: r.spacingS),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final ancho in const [0.7, 0.45])
              FractionallySizedBox(
                widthFactor: ancho,
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(bottom: r.spacingXS / 2),
                  decoration: BoxDecoration(
                    color: onBg.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
