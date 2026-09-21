// ─────────────────────────────────────────────────────────────
// home_movil_overlay.dart — PART de home_movil.dart: overlay de
// bloqueo que cubre la Home móvil mientras se adquieren las
// sesiones de las fuentes de música ("Preparando tus fuentes…")
// con un botón para saltar la espera. Asegura que el usuario no
// use la app sin sesiones listas (o que pueda continuar si el
// backend se atascó).
// Se conecta con: home_movil.dart (misma library).
// Parte del flujo: Home (variante móvil, arranque).
// ─────────────────────────────────────────────────────────────

part of 'home_movil.dart';

/// Overlay de "Preparando fuentes" con opción de saltar.
class _OverlayPreparacion extends StatelessWidget {
  final VoidCallback? onSaltarEspera;

  const _OverlayPreparacion({this.onSaltarEspera});

  @override
  Widget build(BuildContext context) {
    final nav = AppLocalizations.of(context).nav;
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.82),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  nav.preparando,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  nav.preparandoAviso,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (onSaltarEspera != null)
                  TextButton.icon(
                    onPressed: onSaltarEspera,
                    icon: const Icon(Icons.skip_next, size: 20),
                    label: Text(nav.continuar),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white12,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
