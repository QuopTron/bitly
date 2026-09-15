// ─────────────────────────────────────────────────────────────
// pagina_mi_espacio_boton_busqueda.dart — PART de
// pagina_mi_espacio.dart: botón circular que abre/cierra el
// acordeón de búsqueda en la fila superior de Mi Espacio. Vive
// arriba (no abajo) porque el miniplayer tapa la esquina inferior.
// Se conecta con: pagina_mi_espacio.dart (misma library) +
// pagina_mi_espacio_cuerpo (lo usa en la fila superior).
// Parte del flujo: Home → Mi Espacio → búsqueda de canciones.
// ─────────────────────────────────────────────────────────────

part of 'pagina_mi_espacio.dart';

/// Botón de búsqueda compacto para la fila superior de Mi Espacio.
/// Cambia de icono (lupa ↔ lupa tachada) con una transición suave.
class _BotonBusquedaToggle extends StatelessWidget {
  final bool activo;
  final Color onBg;
  final VoidCallback onTap;

  const _BotonBusquedaToggle({
    required this.activo,
    required this.onBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: activo
                ? onBg.withValues(alpha: 0.15)
                : onBg.withValues(alpha: 0.05),
            border: Border.all(
              color: activo
                  ? onBg.withValues(alpha: 0.4)
                  : onBg.withValues(alpha: 0.1),
              width: activo ? 1.0 : 0.6,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              activo ? Icons.search_off_rounded : Icons.search_rounded,
              key: ValueKey(activo),
              size: 20,
              color: activo ? onBg : onBg.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
