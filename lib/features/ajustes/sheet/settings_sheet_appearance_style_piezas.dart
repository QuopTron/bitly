// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_style_piezas.dart — PART de
// settings_sheet_new.dart: las piezas chicas del bloque Estilo con cover.
//
// Son dos y ninguna tiene estado:
//   _porcentaje        → el valor del slider leído como porcentaje,
//   _ChipPersonalizado → la etiqueta "Personalizado" cuando las zonas no
//                        están todas al mismo nivel.
// El botón "i" vive en settings_sheet_appearance_estilo_info.dart.
//
// Se conecta con: settings_sheet_appearance_style.dart (las usa) y
// settings_sheet_appearance_granular.dart (reusa _porcentaje).
// Parte del flujo: Ajustes → Apariencia → Estilo con cover.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Valor del slider como porcentaje: es como se lee una intensidad.
String _porcentaje(double valor) => '${(valor * 100).round()}%';

/// Chip "Personalizado" que aparece cuando las zonas no están todas iguales.
class _ChipPersonalizado extends StatelessWidget {
  final String texto;
  final Color glowColor;
  final Responsive r;

  const _ChipPersonalizado({
    required this.texto,
    required this.glowColor,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.spacingXS + 2, vertical: 1),
      decoration: BoxDecoration(
        color: glowColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: glowColor.withValues(alpha: 0.35)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: r.footerSize - 2,
          fontWeight: FontWeight.w700,
          color: glowColor,
        ),
      ),
    );
  }
}

/// Botón "i" del encabezado: abre la explicación de la opacidad.
class _BotonInfoEstilo extends StatelessWidget {
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onTap;

  const _BotonInfoEstilo({
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          // Área de toque cómoda sin agrandar el ícono.
          padding: EdgeInsets.all(r.spacingXS),
          child: Icon(
            Icons.info_outline_rounded,
            size: r.subtitleSize - 2,
            color: onBg.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}
