// ─────────────────────────────────────────────────────────────
// mi_espacio_movil.dart — Variante móvil de Mi Espacio: columna
// full-width con la cabecera (perfil + banner) arriba y el cuerpo
// (pestañas + contenido) en un Expanded. Todo viene construido
// desde la página para no duplicar lógica entre variantes.
// Se conecta con: pagina_mi_espacio.dart (padre).
// Parte del flujo: Home → Mi Espacio (diseño Android actual).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../shared/utilidades/plataforma/responsive.dart';

/// Layout móvil de Mi Espacio (diseño Android actual).
class MiEspacioMovil extends StatelessWidget {
  final Widget cabecera;
  final Widget cuerpo;

  const MiEspacioMovil({
    super.key,
    required this.cabecera,
    required this.cuerpo,
  });

  @override
  Widget build(BuildContext context) {
    // La separación cabecera/cuerpo sale de Responsive (crece con la pantalla
    // y con el aparato), no de un 8 fijo.
    final r = Responsive(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cabecera,
        SizedBox(height: r.spacingS),
        Expanded(child: cuerpo),
      ],
    );
  }
}
