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

part of '../base/home_movil.dart';

/// Overlay de "Preparando fuentes" con opción de saltar.
class _OverlayPreparacion extends StatelessWidget {
  final VoidCallback? onSaltarEspera;

  const _OverlayPreparacion({this.onSaltarEspera});

  @override
  Widget build(BuildContext context) {
    final nav = AppLocalizations.of(context).nav;
    // El aviso de espera también mide por aparato: en la tele el texto y el
    // botón crecen (y el botón pasa a ser un blanco grande para el puntero).
    final r = Responsive(context);
    final esp = EspecificacionesPlataforma.de(context);
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.82),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                SizedBox(height: r.spacingXL),
                Text(
                  nav.preparando,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.sobre(16, 24),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: r.spacingS),
                Text(
                  nav.preparandoAviso,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: r.sobre(13, 19),
                  ),
                ),
                SizedBox(height: r.spacingM),
                if (onSaltarEspera != null)
                  TextButton.icon(
                    onPressed: onSaltarEspera,
                    icon: Icon(Icons.skip_next, size: esp.iconoAccion),
                    label: Text(nav.continuar),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white12,
                      minimumSize: Size(0, esp.altoBoton),
                      padding: EdgeInsets.symmetric(
                        horizontal: r.spacingXL,
                        vertical: r.spacingM,
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
