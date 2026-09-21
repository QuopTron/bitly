// ─────────────────────────────────────────────────────────────
// tarjeta_track_fondo.dart — PART de tarjeta_track.dart: capas de
// fondo del cuerpo de la tarjeta — portada de fondo (siempre), capa
// de tinte con el color dominante cuya OPACIDAD es la intensidad,
// velo y gradiente inferior para que el texto quede legible.
//
// La portada no se borra al mover el control: con 1% se ve la
// carátula con un 1% de su color encima, y recién al 100% el color
// pasa a ser el fondo principal. El velo y la sombra se cruzan entre
// el valor de Normal y el del color, así el primer punto del slider
// no pega un salto.
//
// Se conecta con: tarjeta_track.dart (misma library) + imagen_portada
// + colores_app + estilo_helper + atenuado_por_nivel.
// Parte del flujo: búsqueda, feed, mi espacio (filas de tracks).
// ─────────────────────────────────────────────────────────────

part of 'tarjeta_track.dart';

/// Capas de fondo apiladas detrás del contenido de la tarjeta de track.
List<Widget> _capasFondoTrack(
  TarjetaTrack t,
  Color fg,
  bool esOscuro,
  Color? acento,
  double nivel,
  bool efectosPesados,
) {
  final tieneCover = t.coverUrl != null && t.coverUrl!.isNotEmpty;
  final hayColor = acento != null && nivel > 0;
  final fondoCard = ColoresApp.superficie(esOscuro);
  // La intensidad entra 1:1: al 1% hay 1% de tinte y al 100% el color manda,
  // sin curvas que concentren el cambio en un tramo del control.
  final v = nivel;

  // Velo: el de siempre sobre la foto, el del color cuando el cover manda.
  final veloNormal = ColoresApp.sombra(esOscuro).withValues(alpha: 0.4);
  final veloColor =
      hayColor
          ? ColoresApp.veloDinamico(esOscuro, acento, alpha: 0.15)
          : veloNormal;
  // Sombra inferior: misma idea, para el degradado de legibilidad.
  final sombraInferior =
      hayColor
          ? ColoresApp.sombraDinamica(esOscuro, acento)
          : ColoresApp.sombra(esOscuro);

  return [
    // Capa 1: la carátula, SIEMPRE. La intensidad no la saca: la va tapando.
    if (tieneCover)
      Positioned.fill(
        child: imagenDesdeUrl(
          t.coverUrl,
          ajuste: BoxFit.cover,
          ancho: 128,
          alto: 128,
        ),
      ),
    // Capa 2: el tinte del color dominante, encima de la foto y con la
    // opacidad de la intensidad. Con nivel 1 es el fondo de "Spotify".
    if (hayColor)
      Positioned.fill(
        child: AtenuadoPorNivel(
          opacidad: v,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                // El color del cover con presencia (si no, sobre su propia
                // foto quedaba casi igual y el control no se notaba).
                colors: [
                  EstiloHelper.colorDeCover(acento, fondoCard),
                  EstiloHelper.colorDeCover(acento, fondoCard, mezcla: 0.42),
                ],
              ),
            ),
          ),
        ),
      ),
    // Capa 3: velo de legibilidad (se cruza entre los dos looks).
    Positioned.fill(
      child: ColoredBox(
        color: EstiloHelper.mezclarColor(veloNormal, veloColor, v),
      ),
    ),
    // Capa 4: degradado inferior, con el tono de sombra que corresponda.
    Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              fg.withValues(alpha: esOscuro ? 0.05 : 0.0),
              Colors.transparent,
              sombraInferior.withValues(alpha: efectosPesados ? 0.45 : 0.3),
            ],
            stops: const [0.0, 0.35, 1.0],
          ),
        ),
      ),
    ),
  ];
}
