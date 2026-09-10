// ─────────────────────────────────────────────────────────────
// esqueleto_detalle.dart — Esqueleto de carga (shimmer) para las
// páginas de detalle: un círculo grande (portada) y una fila
// (texto) centrados, reutilizando la base EsqueletoCarga con el
// mismo ritmo de animación del resto de la app.
// Se conecta con: esqueleto_carga (base shimmer) + responsive.
// Parte del flujo: Detalle (estado de carga).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../shared/utilidades/responsive.dart';
import '../../shared/widgets/esqueleto_carga.dart';

/// Esqueleto de detalle: círculo de portada + fila de texto.
class EsqueletoDetalle extends StatelessWidget {
  const EsqueletoDetalle({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(180 / 2),
            child: SizedBox(
              width: 180,
              height: 180,
              child: EsqueletoCarga(radioBorde: 0),
            ),
          ),
          SizedBox(height: 24),
          EsqueletoCarga(
            ancho: r.val(200, 240, 280),
            alto: 16,
          ),
        ],
      ),
    );
  }
}