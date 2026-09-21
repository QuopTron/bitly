// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_diseno_restablecer.dart — PART de
// settings_sheet_new.dart: el botón que devuelve el diseño del bloque
// "Diseño" (borde, redondeo y separación) al que trae la app.
//
// Se conecta con: settings_sheet_appearance_diseno.dart (misma library).
// Parte del flujo: Ajustes → Apariencia → Diseño.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Botón de "volver a como venía": texto + qué revierte. Lo usan el bloque
/// Diseño (borde, separación y redondeo) y el de Estilo visual (Clásico con
/// los componentes apagados).
class _BotonRestablecer extends StatelessWidget {
  final String texto;
  final VoidCallback onPressed;

  const _BotonRestablecer({required this.texto, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glow = isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        Icons.restart_alt_rounded,
        size: r.footerSize + 2,
        color: glow,
      ),
      label: Text(texto, style: TextStyle(fontSize: r.footerSize, color: glow)),
    );
  }
}
