// ─────────────────────────────────────────────────────────────
// settings_sheet_nav_riel_tv.dart — PART de settings_sheet_new.dart:
// el RIEL lateral de Ajustes para TV.
//
// Por qué no reusa el de PC: en una tele el riel se maneja con el
// puntero del control a metros de distancia, así que va más ANCHO, con
// filas más altas y el ícono y el nombre más grandes (la escala la
// aplica _RielItem con `esTv`), y llega hasta el borde inferior en vez
// de flotar con margen — así los ítems quedan en una columna larga y
// previsible en vez de apretados en el medio.
//
// Se conecta con: settings_sheet_nav.dart (lo elige cuando la pantalla
// es TV), settings_sheet_nav_riel_item.dart (la fila, en escala de TV) y
// settings_sheet_entry.dart (íconos y orden de las pestañas).
// Parte del flujo: Ajustes → navegación (TV).
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Riel vertical de TV: más ancho, filas grandes y a toda la altura.
class _RielAjustesTv extends StatelessWidget {
  final int? currentIndex;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final void Function(int index) onTap;

  const _RielAjustesTv({
    required this.currentIndex,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final etiquetas = AppLocalizations.of(context).ajustes.pestanas;
    // Más ancho que en PC: a tres metros una fila angosta no se lee.
    final ancho = (r.width * 0.30).clamp(280.0, 360.0);

    return Container(
      width: ancho,
      // Sin margen inferior: el riel acompaña toda la altura de la pantalla.
      margin: EdgeInsets.only(left: r.spacingM, right: r.spacingM),
      padding: EdgeInsets.symmetric(
        vertical: r.spacingM,
        horizontal: r.spacingXS,
      ),
      decoration: BoxDecoration(
        color: onBg.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: onBg.withValues(alpha: 0.08)),
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
                esTv: true,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
  }
}
