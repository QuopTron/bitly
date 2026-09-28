// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_vistas_controles.dart — PART de
// settings_sheet_new.dart: las piezas con las que se cambia UN eje del diseño
// de una vista (tipografía, redondeo, aire).
//
// Van aparte de la tarjeta para que cada archivo haga una sola cosa: acá está
// CÓMO se elige, en la tarjeta está QUÉ se elige.
//
// Se conecta con: settings_sheet_appearance_vistas.dart (la tarjeta).
// Parte del flujo: Ajustes → Apariencia → Vistas.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Un chip de opción elegible (tipografía, tamaño...). Lo comparten la tarjeta
/// de tipografía/diseño por vista y la de barras: es el mismo control.
class _ChipOpcion extends StatelessWidget {
  final String texto;
  final bool seleccionado;

  /// Familia con la que se escribe la opción. null = la del tema.
  final String? familia;
  final Responsive r;
  final Color onBg;
  final Color glowColor;
  final VoidCallback onTap;

  const _ChipOpcion({
    required this.texto,
    required this.seleccionado,
    required this.r,
    required this.onBg,
    required this.glowColor,
    required this.onTap,
    this.familia,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Haptico.tap();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.spacingS,
          vertical: r.spacingXS + 2,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color:
              seleccionado
                  ? glowColor.withValues(alpha: 0.16)
                  : onBg.withValues(alpha: 0.04),
          border: Border.all(
            color:
                seleccionado
                    ? glowColor.withValues(alpha: 0.55)
                    : onBg.withValues(alpha: 0.10),
          ),
        ),
        // El nombre se escribe EN su tipografía: se elige mirando, no leyendo
        // una lista de nombres.
        child: Text(
          texto,
          style: TextStyle(
            fontFamily: familia,
            fontSize: r.footerSize - 1,
            fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
            color: seleccionado ? onBg : onBg.withValues(alpha: 0.65),
          ),
        ),
      ),
    );
  }
}

/// Rótulo de un eje con la marca de si la vista lo tocó o lo hereda, y la salida
/// rápida para volver a heredarlo.
class _VistasEje extends StatelessWidget {
  final String rotulo;
  final bool propio;

  /// Texto de la marca cuando NO es propio. Por defecto dice "Heredado", pero
  /// las columnas no heredan del estilo global: cuando no las toca las decide
  /// el ancho de la pantalla, así que ahí se dice "Automático".
  final String? marcaVacia;
  final StringsVistas t;
  final Responsive r;
  final Color onBg;
  final Color glowColor;
  final VoidCallback onHeredar;
  final Widget child;

  const _VistasEje({
    required this.rotulo,
    required this.propio,
    required this.t,
    required this.r,
    required this.onBg,
    required this.glowColor,
    required this.onHeredar,
    required this.child,
    this.marcaVacia,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                rotulo,
                style: TextStyle(
                  fontSize: r.footerSize,
                  fontWeight: FontWeight.w600,
                  color: onBg.withValues(alpha: 0.85),
                ),
              ),
            ),
            _marca(),
            if (propio)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Haptico.tap();
                  onHeredar();
                },
                child: Padding(
                  padding: EdgeInsets.only(left: r.spacingS),
                  child: Text(
                    t.heredar,
                    style: TextStyle(
                      fontSize: r.footerSize - 1,
                      fontWeight: FontWeight.w600,
                      color: glowColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
        child,
      ],
    );
  }

  /// La etiqueta que dice de quién es el valor.
  Widget _marca() => Container(
    padding: EdgeInsets.symmetric(horizontal: r.spacingXS + 2, vertical: 1),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color:
            propio
                ? glowColor.withValues(alpha: 0.45)
                : onBg.withValues(alpha: 0.12),
      ),
    ),
    child: Text(
      propio ? t.propio : (marcaVacia ?? t.heredado),
      style: TextStyle(
        fontSize: r.footerSize - 3,
        fontWeight: FontWeight.w600,
        color: propio ? glowColor : onBg.withValues(alpha: 0.45),
      ),
    ),
  );
}
