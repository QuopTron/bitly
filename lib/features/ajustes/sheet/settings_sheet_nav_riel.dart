// ─────────────────────────────────────────────────────────────
// settings_sheet_nav_riel.dart — PART de settings_sheet_new.dart: el
// RIEL lateral de Ajustes para pantalla ancha (PC, TV, tablet apaisada).
//
// Con ancho de sobra, una fila de 7 burbujas dejaría las etiquetas perdidas
// en el centro: acá van apiladas a la izquierda, con el ícono en un recuadro,
// el nombre completo y un halo en la pestaña activa. El contenido ocupa el
// resto y nada se aprieta.
//
// Se conecta con: settings_sheet_nav.dart (lo elige),
// settings_sheet_nav_riel_item.dart (la fila) y settings_sheet_entry.dart
// (íconos y orden de las pestañas).
// Parte del flujo: Ajustes → navegación (pantalla ancha).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Riel vertical de pestañas. Ancho acotado: cómodo para el texto, sin
/// robarle espacio al contenido en pantallas muy grandes.
class _RielAjustes extends StatelessWidget {
  final int? currentIndex;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final void Function(int index) onTap;

  const _RielAjustes({
    required this.currentIndex,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final etiquetas = AppLocalizations.of(context).ajustes.pestanas;
    final ancho = (r.width * 0.26).clamp(180.0, 250.0);

    return Container(
      width: ancho,
      margin: EdgeInsets.only(
        left: r.spacingM,
        right: r.spacingS,
        bottom: r.spacingM,
      ),
      padding: EdgeInsets.symmetric(
        vertical: r.spacingS,
        horizontal: r.spacingXS,
      ),
      decoration: BoxDecoration(
        color: onBg.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: onBg.withValues(alpha: 0.07)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _iconosPestanas.length; i++)
              _RielItem(
                index: i,
                etiqueta: etiquetas[i],
                active: currentIndex == i,
                glowColor: glowColor,
                onBg: onBg,
                r: r,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
  }
}
