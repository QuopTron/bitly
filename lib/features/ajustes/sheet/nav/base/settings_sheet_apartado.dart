// ─────────────────────────────────────────────────────────────
// settings_sheet_apartado.dart — PART de settings_sheet_new.dart:
// encabezado de apartado (título + bajada) que usan las pestañas que
// nacieron al abrir "Más" en Cuenta y Proveedores.
//
// Deja una frase que explique de qué va la pestaña: al separar los
// apartados, el usuario que entra por primera vez ya sabe qué esperar.
//
// Se conecta con: settings_sheet_cuenta_tab.dart y
// settings_sheet_proveedores_tab.dart (misma library).
// Parte del flujo: Ajustes → Cuenta / Proveedores.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Título de apartado con su bajada, alineado a la izquierda.
class _TituloApartado extends StatelessWidget {
  final String titulo;
  final String bajada;
  final Color glowColor;

  const _TituloApartado({
    required this.titulo,
    required this.bajada,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: r.titleSize,
            fontWeight: FontWeight.w800,
            color: onBg,
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: 2),
        // Regla corta con el acento: separa el título del contenido sin
        // ocupar una línea entera.
        Container(
          width: 26,
          height: 2,
          decoration: BoxDecoration(
            color: glowColor,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        SizedBox(height: r.spacingXS),
        Text(
          bajada,
          style: TextStyle(
            fontSize: r.footerSize - 1,
            color: onBg.withValues(alpha: 0.5),
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
