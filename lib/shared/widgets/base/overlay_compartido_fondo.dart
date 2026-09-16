// ─────────────────────────────────────────────────────────────
// overlay_compartido_fondo.dart — PART de
// overlay_compartido_contenido.dart: el fondo del overlay.
//
// No tapa la app: la DESENFOCA con fuerza y le pone un velo del color
// de la superficie, más una viñeta suave para que la carta resalte.
//
// DETALLE IMPORTANTE: en los equipos de gama baja el perfil apaga los
// desenfoques (EfectosApp), así que acá no queda blur y el velo es el
// que tiene que hacer el trabajo. Por eso su opacidad sube bastante
// cuando no hay blur: si no, el fondo no se distinguía de la app y
// parecía que la carta flotaba sobre la pantalla normal.
//
// Es un widget ESTÁTICO: el dueño (OverlayCompartido) lo monta fuera de
// la animación de entrada, así que se construye una sola vez y no se
// repinta en cada frame mientras la carta cae.
//
// Tocar el fondo (fuera de la carta) cierra el overlay.
//
// Se conecta con: overlay_compartido_contenido.dart (misma library) +
// desenfoque_adaptativo + efectos_app.
// Parte del flujo: enlace compartido → carta → reproducir/encolar.
// ─────────────────────────────────────────────────────────────

part of 'overlay_compartido_contenido.dart';

/// Fondo del overlay: desenfoca lo de atrás, lo vela y cierra al tocar.
class FondoCompartido extends StatelessWidget {
  /// Se llama al tocar fuera de la carta.
  final VoidCallback onDismiss;

  const FondoCompartido({super.key, required this.onDismiss});

  /// Radio del desenfoque. Lo recorta EfectosApp al tope del perfil.
  static const double sigma = 26;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final conBlur = EfectosApp.desenfoqueActivo;

    // Sin blur el velo es el único separador → bien opaco. Con blur
    // alcanza con asentar el contraste.
    final velo = cs.surface.withValues(alpha: conBlur ? 0.34 : 0.78);
    // Viñeta: aclara/oscurece los bordes según el tema.
    final refuerzo = esOscuro ? Colors.black : Colors.white;
    final vineta = refuerzo.withValues(alpha: conBlur ? 0.26 : 0.38);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            DesenfoqueAdaptativo(
              sigma: sigma,
              child: ColoredBox(color: velo, child: const SizedBox.expand()),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.95,
                  colors: [refuerzo.withValues(alpha: 0), vineta],
                  stops: const [0.45, 1],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ],
        ),
      ),
    );
  }
}
