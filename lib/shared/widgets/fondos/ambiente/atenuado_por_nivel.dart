// ─────────────────────────────────────────────────────────────
// atenuado_por_nivel.dart — Pinta [child] con una opacidad, pero SIN pagar
// la capa cuando no hace falta: con opacidad 1 lo devuelve tal cual (un
// `Opacity` de 1 igual hace un saveLayer) y con opacidad 0 no pinta nada.
//
// Lo usan los fondos que ahora se cruzan por intensidad (cover difuminado
// que se va, color del cover que entra): son capas A PANTALLA COMPLETA, así
// que una capa de más se nota en los equipos de gama baja.
//
// Se conecta con: fondo_ambiente, reproductor_pagina_fondo,
// velo_cola_estilo_state, fondo_reactivo_portada, cabecera_detalle_fondo y
// settings_sheet_background.
// Parte del flujo: pintado del estilo con cover.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/widgets.dart';

/// Atenúa su hijo: lo devuelve intacto con [opacidad] 1 y no lo pinta con 0.
class AtenuadoPorNivel extends StatelessWidget {
  final double opacidad;
  final Widget child;

  const AtenuadoPorNivel({
    super.key,
    required this.opacidad,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (opacidad <= 0) return const SizedBox.shrink();
    if (opacidad >= 1) return child;
    return Opacity(opacity: opacidad, child: child);
  }
}
