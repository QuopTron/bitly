// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_estilo_previa_card.dart — PART de
// settings_sheet_new.dart: la mini tarjeta de canción de la vista
// previa (carátula + dos barras de texto) y el arte de ejemplo.
//
// Es la zona "cards de canción" en miniatura: el borde se cruza con
// el color del cover igual que en tarjeta_track_cuerpo, así el panel
// muestra de verdad lo que va a pasar en las cards.
//
// Se conecta con: settings_sheet_appearance_estilo_previa_panel.dart
// (la monta) + estilo_helper + colores_app.
// Parte del flujo: Ajustes → Apariencia → Estilo con cover.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Carátula de ejemplo cuando no hay ninguna canción sonando: sin ella la
/// vista previa no tendría qué mostrar y el control parecería no hacer nada.
const _gradienteEjemplo = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF3B2A63), Color(0xFF8E4B6B), Color(0xFFD98F56)],
);

/// El color del cover de la carátula de ejemplo.
const acentoDeEjemplo = Color(0xFF9B4F63);

/// Arte de ejemplo (degradado) para cuando no hay canción sonando.
Widget arteDeEjemplo() =>
    const DecoratedBox(decoration: BoxDecoration(gradient: _gradienteEjemplo));

/// Mini tarjeta de canción: carátula + dos barras de texto (esqueleto).
class _MiniCardPrevia extends StatelessWidget {
  final double nivel;
  final Color acento;
  final Widget arte;
  final bool esOscuro;
  final Responsive r;

  const _MiniCardPrevia({
    required this.nivel,
    required this.acento,
    required this.arte,
    required this.esOscuro,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final bordeNormal = Colors.white.withValues(alpha: 0.12);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color:
              nivel > 0
                  ? EstiloHelper.mezclarColor(
                    bordeNormal,
                    ColoresApp.bordeDinamico(esOscuro, acento),
                    nivel,
                  )
                  : bordeNormal,
        ),
      ),
      padding: EdgeInsets.all(r.spacingXS * 0.6),
      child: Row(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: arte,
            ),
          ),
          SizedBox(width: r.spacingXS * 0.6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _barraPrevia(0.75),
                SizedBox(height: r.spacingXS * 0.5),
                _barraPrevia(0.45),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Una barra del esqueleto de texto.
  Widget _barraPrevia(double factor) => FractionallySizedBox(
    alignment: Alignment.centerLeft,
    widthFactor: factor,
    child: Container(
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}
