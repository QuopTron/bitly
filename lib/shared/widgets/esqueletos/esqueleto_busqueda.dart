// ─────────────────────────────────────────────────────────────
// esqueleto_busqueda.dart — Esqueleto shimmer de búsqueda: sin
// categoría activa muestra cabeceras + tracks + grilla; 'tracks'
// solo tarjetas de track; otra categoría solo la grilla. Replica
// el layout de los resultados reales. Las piezas (tarjeta de
// track, cabecera, grilla) viven en el part
// esqueleto_busqueda_sub.dart.
// Se conecta con: nada (solo tema del context).
// Parte del flujo: búsqueda (loading mientras llegan resultados).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../tema/especificaciones/especificaciones_plataforma.dart';
import '../../utilidades/plataforma/responsive.dart';

part 'esqueleto_busqueda_sub.dart';

/// Esqueleto que imita el layout de los resultados de búsqueda.
class EsqueletoBusqueda extends StatelessWidget {
  final String? tipoSeleccionado;

  const EsqueletoBusqueda({super.key, this.tipoSeleccionado});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final base =
        oscuro
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05);
    final brillo =
        oscuro
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08);

    // Vista por defecto (sin chip): cabeceras + tracks + grilla.
    if (tipoSeleccionado == null) {
      return ListView(
        padding: EdgeInsets.symmetric(
          horizontal: r.spacingM,
          vertical: r.spacingS,
        ),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _EncabezadoSeccion(base: base, brillo: brillo),
          SizedBox(height: r.spacingS),
          ...List.generate(
            4,
            (_) => _TarjetaTrackEsqueleto(base: base, brillo: brillo),
          ),
          SizedBox(height: r.spacingM),
          _EncabezadoSeccion(base: base, brillo: brillo),
          SizedBox(height: r.spacingS),
          _GrillaEsqueleto(base: base, brillo: brillo),
        ],
      );
    }

    // Solo tracks: tarjetas de track.
    if (tipoSeleccionado == 'tracks') {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(
          6,
          (_) => _TarjetaTrackEsqueleto(base: base, brillo: brillo),
        ),
      );
    }

    // Otras categorías: solo grilla.
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      children: [_GrillaEsqueleto(base: base, brillo: brillo)],
    );
  }
}
