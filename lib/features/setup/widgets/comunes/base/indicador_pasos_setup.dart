// ─────────────────────────────────────────────────────────────
// indicador_pasos_setup.dart — Indicador de pasos del setup: un punto por
// paso, con el actual alargado y los ya hechos encendidos.
//
// Vive aparte porque lo usan las TRES variantes del setup (celular, PC y TV):
// antes cada una llevaba su copia del mismo Row con sus mismos índices, y con
// tres variantes eso ya era triplicar la misma cuenta.
//
// Se conecta con: setup_movil, setup_escritorio y setup_tv.
// Parte del flujo: setup (bienvenida).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../../shared/tema/colores_app.dart';
import '../../../../../shared/tema/especificaciones/especificaciones_plataforma.dart';
import '../../../../../shared/utilidades/plataforma/responsive.dart';
import '../../../bloc/base/setup_estado.dart';

/// Cuántos puntos muestra el indicador (los pasos visibles del setup).
const int pasosVisiblesSetup = 7;

/// Indicador de pasos del setup.
class IndicadorPasosSetup extends StatelessWidget {
  final PasoSetup paso;

  /// Tema oscuro: cambia el acento y el color de los puntos apagados.
  final bool esOscuro;

  /// Separación BASE entre puntos: el aparato la escala (en la tele, que se
  /// mira de lejos, queda más aireada sola). Antes cada variante pasaba su
  /// propio número y la TV repetía el ajuste a mano.
  final double separacion;

  const IndicadorPasosSetup({
    super.key,
    required this.paso,
    required this.esOscuro,
    this.separacion = 3,
  });

  /// Posición del punto según el paso: los primeros comparten el 0 y los
  /// últimos el 6, porque son la misma pantalla en estados distintos
  /// (prompt/idioma/chequeo, y verificación/gracias).
  static int indiceDe(PasoSetup paso) => switch (paso) {
    PasoSetup.promptReingreso ||
    PasoSetup.idioma ||
    PasoSetup.chequeandoExistente => 0,
    PasoSetup.usuario => 1,
    PasoSetup.googleSignIn => 2,
    PasoSetup.modo => 3,
    PasoSetup.carpetaAlmacenamiento => 4,
    PasoSetup.notificaciones => 5,
    PasoSetup.verificacion || PasoSetup.gracias => 6,
  };

  @override
  Widget build(BuildContext context) {
    final indice = indiceDe(paso);
    final acento = esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
    final onBg = esOscuro ? Colors.white : Colors.black;
    // Los puntos salen del aparato: en la tele el indicador crece junto con
    // el resto del setup (a tres metros un punto de 8 no se ve).
    final r = Responsive(context);
    final altoPunto =
        EspecificacionesPlataforma.de(context).altoIndicador *
        0.34; // 8 en celu
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < pasosVisiblesSetup; i++)
          Container(
            width: i == indice ? r.sobre(22, 34) : altoPunto,
            height: altoPunto,
            margin: EdgeInsets.symmetric(horizontal: separacion * r.factor),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(altoPunto / 2),
              color: i <= indice ? acento : onBg.withValues(alpha: 0.15),
            ),
          ),
      ],
    );
  }
}
