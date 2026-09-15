// ─────────────────────────────────────────────────────────────
// tarjeta_track_fondo.dart — PART de tarjeta_track.dart: capas de
// fondo del cuerpo de la tarjeta — portada borrosa en modo Clásico,
// gradiente del color dominante en modo Spotify, velo y gradiente
// inferior para que el texto quede legible sobre el arte.
// Se conecta con: tarjeta_track.dart (misma library) + imagen_portada
// + colores_app.
// Parte del flujo: búsqueda, feed, mi espacio (filas de tracks).
// ─────────────────────────────────────────────────────────────

part of 'tarjeta_track.dart';

/// Capas de fondo apiladas detrás del contenido de la tarjeta de track.
List<Widget> _capasFondoTrack(
  TarjetaTrack t,
  Color fg,
  bool esOscuro,
  Color? acento,
  bool efectosPesados,
) {
  return [
    // En modo Clásico: portada de fondo. En Spotify: color dominante.
    if (acento == null && t.coverUrl != null && t.coverUrl!.isNotEmpty)
      Positioned.fill(
        child: imagenDesdeUrl(
          t.coverUrl,
          ajuste: BoxFit.cover,
          ancho: 128,
          alto: 128,
        ),
      ),
    if (acento != null)
      Positioned.fill(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(ColoresApp.superficie(esOscuro), acento, 0.45)!,
                Color.lerp(ColoresApp.superficie(esOscuro), acento, 0.20)!,
              ],
            ),
          ),
        ),
      ),
    Positioned.fill(
      child: Container(
        // En Spotify el fondo ya es el color dominante, velo más sutil.
        color: acento != null
            ? ColoresApp.veloDinamico(esOscuro, acento, alpha: 0.15)
            : ColoresApp.sombra(esOscuro).withValues(alpha: 0.4),
      ),
    ),
    Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              fg.withValues(alpha: esOscuro ? 0.05 : 0.0),
              Colors.transparent,
              (acento != null
                      ? ColoresApp.sombraDinamica(esOscuro, acento)
                      : ColoresApp.sombra(esOscuro))
                  .withValues(alpha: efectosPesados ? 0.45 : 0.3),
            ],
            stops: const [0.0, 0.35, 1.0],
          ),
        ),
      ),
    ),
  ];
}
