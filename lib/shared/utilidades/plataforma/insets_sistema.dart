// ─────────────────────────────────────────────────────────────
// insets_sistema.dart — Inset inferior REAL del sistema (el menú de
// navegación del celular: atrás / home / recientes).
//
// Por qué existe: muchas partes de la app se anclan al borde FÍSICO de la
// pantalla y nunca consumen ese inset, así que las 3 teclas del celular tapan
// sus últimos botones. Los casos que cubre este helper:
//
//   - hojas modales (`showModalBottomSheet`): se anclan al borde físico y el
//     contenido no reserva la zona del menú de navegación;
//   - páginas de detalle: el espaciador inferior solo contaba el chrome
//     flotante (miniplayer + navbar propios), no el menú del sistema;
//   - shell móvil: la columna miniplayer + navbar se apoya en el borde.
//
// Usa [MediaQuery.padding]: es el inset que NADIE consumió todavía, así que no
// se reserva dos veces la misma zona cuando el widget ya está dentro de un
// `SafeArea` (ahí `padding` vale 0 y este helper también devuelve 0).
// Con el teclado abierto `padding.bottom` vale 0: correcto, el teclado ocupa
// esa franja.
//
// Se conecta con: home_movil, hojas de ajustes/descarga/cola y las páginas de
// detalle.
// Parte del flujo: presentación (área segura del sistema).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// Alto REAL (en dp) que el menú de navegación del sistema ocupa abajo y que
/// todavía no fue reservado por ningún ancestro.
double insetInferiorSistema(BuildContext context) {
  return MediaQuery.paddingOf(context).bottom;
}

/// Alto REAL (en dp) de la barra de estado / notch arriba.
double insetSuperiorSistema(BuildContext context) {
  return MediaQuery.paddingOf(context).top;
}

/// Reserva el inset inferior del sistema alrededor de [child].
///
/// No toca izquierda/derecha/arriba: solo garantiza que nada quede debajo del
/// menú de navegación del celular.
class ReservaInferiorSistema extends StatelessWidget {
  final Widget child;

  const ReservaInferiorSistema({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final inset = insetInferiorSistema(context);
    if (inset <= 0) return child;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: child,
    );
  }
}
