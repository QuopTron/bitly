// PART de home_movil.dart: barra inferior del shell móvil — miniplayer
// encima de la navbar flotante, anclada al pie y reservando el menú de
// navegación del sistema (atrás / home / recientes) para que nunca tape
// los controles.
//
// El margen lateral y el ancho máximo del miniplayer los decide su GEOMETRÍA
// (MarcoMiniplayer): con la forma de siempre el margen vale 0 (pegado al borde,
// sin hueco contra la navbar) y con la flotante deja la tarjeta separada.

part of '../base/home_movil.dart';

/// Miniplayer + navbar flotante al pie del shell móvil.
class _BarraInferiorShell extends StatelessWidget {
  final Widget miniPlayer;
  final bool isDark;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BarraInferiorShell({
    required this.miniPlayer,
    required this.isDark,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      // Reserva el alto del menú de navegación del celular: sin esto las 3
      // teclas del sistema tapan los controles del miniplayer y la navbar.
      child: ReservaInferiorSistema(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MarcoMiniplayer(child: miniPlayer),
            BarraNavegacionFlotante(
              isDark: isDark,
              currentIndex: currentIndex,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}
