// ─────────────────────────────────────────────────────────────
// contenido_con_alto_minimo.dart — Da a su hijo un alto ACOTADO (nunca
// infinito) y, si la pantalla es más baja que [altoMinimo], permite desplazar.
//
// Por qué existe: los slides del setup están armados con Column + Spacer +
// Expanded, que EXIGEN un alto acotado. En pantallas bajas (o cuando el usuario
// sube el tamaño de fuente o el tamaño de pantalla) el contenido fijo supera el
// alto disponible y el slide desborda: el botón de "Continuar" queda fuera y el
// usuario no puede avanzar el setup.
//
// Con este envoltorio el slide siempre recibe un alto concreto — así Spacer y
// Expanded siguen funcionando y no hay overflow — y si la pantalla no alcanza,
// el sobrante se alcanza desplazando en vez de perderse.
//
// Se conecta con: features/setup/vistas (setup_movil y setup_escritorio).
// Parte del flujo: setup (robustez de layout por densidad/tamaño de fuente).
// ─────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Alto mínimo que se le garantiza a un slide del setup. Es el alto que
/// necesita el paso más cargado (tarjetas de Google, carpeta de descargas,
/// notificaciones) para que sus textos y su botón entren incluso con el tamaño
/// de fuente aumentado. Por debajo, el slide se desplaza en vez de desbordar.
const double altoMinimoSlideSetup = 560;

class ContenidoConAltoMinimo extends StatelessWidget {
  /// Alto mínimo garantizado (px lógicos) para el contenido.
  final double altoMinimo;

  /// Contenido que usa Spacer/Expanded y por eso necesita alto acotado.
  final Widget child;

  const ContenidoConAltoMinimo({
    super.key,
    required this.altoMinimo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Si ya hay más alto que el mínimo se usa el real (no hay nada que
        // desplazar); si no, se garantiza el mínimo y se permite scroll.
        final acotado = constraints.hasBoundedHeight && constraints.maxHeight > 0;
        final alto =
            acotado ? math.max(constraints.maxHeight, altoMinimo) : altoMinimo;
        return SingleChildScrollView(
          child: SizedBox(height: alto, child: child),
        );
      },
    );
  }
}
