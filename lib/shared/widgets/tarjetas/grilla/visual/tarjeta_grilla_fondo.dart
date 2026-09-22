// ─────────────────────────────────────────────────────────────
// tarjeta_grilla_fondo.dart — PART de tarjeta_grilla.dart: el fondo
// completo de la tarjeta de grilla, en capas — portada borrosa (o
// gradiente preset), capa de tinte con el color dominante cuya
// OPACIDAD es la intensidad, velo y gradiente ascendente.
//
// La portada NO se borra al subir la intensidad: queda abajo y el
// color del cover la va tapando, así que al 1% se ve la carátula con
// un 1% de su color y recién al 100% el color es el fondo principal.
// El velo y el gradiente se cruzan entre el look Normal y el del
// color para que el primer punto del control no pegue un salto.
//
// Se conecta con: tarjeta_grilla.dart (misma library) + imagen_portada
// + colores_app + estilo_helper + atenuado_por_nivel.
// Parte del flujo: feed, búsqueda, mi espacio (tarjetas de grilla).
// ─────────────────────────────────────────────────────────────

part of '../base/tarjeta_grilla.dart';

/// Fondo de la tarjeta: portada, tinte por intensidad, velo y gradiente.
Widget _fondoTarjeta(
  TarjetaGrilla t,
  BuildContext context,
  bool efectosPesados,
  bool esOscuro,
  Color? acento,
  double nivel,
) {
  final url = t.coverUrl;
  // Un gradiente preset (`gradient:N`) es el arte de la tarjeta: se pinta
  // tal cual y sólo se le suma el tinte del cover delante.
  final esGradiente = url != null && url.startsWith('gradient:');
  final tieneCover = url != null && url.isNotEmpty && !esGradiente;
  final hayColor = acento != null && nivel > 0;
  // La intensidad entra 1:1: cada punto porcentual mueve lo mismo.
  final v = nivel;
  final fondo = ColoresApp.superficie(esOscuro);

  Widget base;
  if (esGradiente) {
    base = _portadaGradienteDe(t, url, 128);
  } else if (tieneCover && efectosPesados) {
    // Portada borrosa: el fondo de siempre.
    base = DesenfoqueHijo(
      sigma: 18,
      child: imagenDesdeUrl(url, ajuste: BoxFit.cover, ancho: 128, alto: 128),
    );
  } else if (tieneCover) {
    // Gama baja: sin desenfoque (una sola textura, casi gratis).
    base = imagenDesdeUrl(url, ajuste: BoxFit.cover, ancho: 128, alto: 128);
  } else {
    base = DecoratedBox(
      decoration: BoxDecoration(gradient: _gradientePlaceholderDe(context)),
    );
  }

  // Velo: el de siempre sobre el arte, el del color cuando el cover manda.
  final veloNormal = ColoresApp.velo(esOscuro).withValues(alpha: 0.45);
  final veloColor =
      hayColor
          ? ColoresApp.veloDinamico(esOscuro, acento, alpha: 0.20)
          : veloNormal;

  /// Una parada del gradiente de legibilidad: el velo de siempre y el del
  /// color, cruzados por la intensidad (así el primer punto no salta).
  Color parada(double alpha) => EstiloHelper.mezclarColor(
    ColoresApp.velo(esOscuro).withValues(alpha: alpha),
    hayColor
        ? ColoresApp.veloDinamico(esOscuro, acento, alpha: alpha)
        : ColoresApp.velo(esOscuro).withValues(alpha: alpha),
    v,
  );

  return Stack(
    fit: StackFit.expand,
    children: [
      // Capa 1: el arte (portada borrosa, preset o placeholder).
      base,
      // Capa 2: tinte del color dominante, con la opacidad de la intensidad.
      if (hayColor)
        AtenuadoPorNivel(
          opacidad: v,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                // El color del cover con presencia (si no, sobre su propia
                // portada quedaba casi igual y el control no se notaba).
                colors: [
                  EstiloHelper.colorDeCover(acento, fondo),
                  EstiloHelper.colorDeCover(acento, fondo, mezcla: 0.40),
                ],
              ),
            ),
          ),
        ),
      // Capa 3: velo de legibilidad (se cruza entre los dos looks).
      ColoredBox(color: EstiloHelper.mezclarColor(veloNormal, veloColor, v)),
      // Capa 4: gradiente ascendente con las paradas ya cruzadas.
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              parada(1.0),
              parada(0.65),
              parada(0.2),
              Colors.transparent,
            ],
            stops: const [0.0, 0.35, 0.7, 1.0],
          ),
        ),
      ),
    ],
  );
}
