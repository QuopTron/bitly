// ─────────────────────────────────────────────────────────────
// reproductor_pagina_gestos.dart — PART de reproductor_pagina.dart:
// gesto de swipe-down para cerrar el reproductor: arrastre con
// límite, opacidad proporcional y animación de regreso o cierre
// según la distancia/velocidad del gesto.
// Se conecta con: reproductor_pagina.dart (misma library).
// Parte del flujo: reproductor (gestos de cierre).
// ─────────────────────────────────────────────────────────────

part of 'reproductor_pagina.dart';

/// Tick de la animación de arrastre: interpola el desplazamiento.
void _enTickArrastre(_ReproductorPaginaState st) {
  final t = Curves.easeOutCubic.transform(st._animArrastre.value);
  st._desplazamiento.value =
      st._arrastreDesde + (st._arrastreHasta - st._arrastreDesde) * t;
}

/// Opacidad según cuánto se arrastró hacia abajo.
double _opacidadArrastre(double dy, double alto) {
  final o = 1.0 - dy / (alto * 0.62);
  if (o < 0) return 0;
  if (o > 1) return 1;
  return o;
}

/// Actualiza el desplazamiento mientras se arrastra (con límite).
void _enArrastre(_ReproductorPaginaState st, DragUpdateDetails detalles) {
  if (st._animArrastre.isAnimating) return;
  final alto = MediaQuery.sizeOf(st.context).height;
  final siguiente = st._desplazamiento.value + detalles.delta.dy;
  st._desplazamiento.value = siguiente < 0
      ? 0
      : (siguiente > alto * 0.92 ? alto * 0.92 : siguiente);
}

/// Termina el arrastre: cierra si pasó el umbral o la velocidad es alta.
void _enFinArrastre(_ReproductorPaginaState st, DragEndDetails detalles) {
  if (st._animArrastre.isAnimating) return;
  final alto = MediaQuery.sizeOf(st.context).height;
  final velocidad = detalles.primaryVelocity ?? 0;
  final debeCerrar = st._desplazamiento.value > alto * 0.08 || velocidad > 700;
  st._arrastreDesde = st._desplazamiento.value;
  st._arrastreHasta = debeCerrar ? alto * 0.95 : 0.0;
  st._animArrastre.forward(from: 0).whenComplete(() {
    if (!st.mounted) return;
    if (debeCerrar) {
      Navigator.of(st.context).pop();
    } else {
      st._desplazamiento.value = 0;
    }
  });
}