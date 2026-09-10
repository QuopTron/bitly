// ─────────────────────────────────────────────────────────────
// mi_espacio_escritorio.dart — Variante escritorio de Mi Espacio:
// panel de contenido centrado (ancho máximo 680px) sobre el fondo
// de la app, con la cabecera (perfil + banner) y el cuerpo
// (pestañas + contenido) ya armados desde la página.
// Se conecta con: pagina_mi_espacio.dart (padre).
// Parte del flujo: Home → Mi Espacio (escritorio/web).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../shared/widgets/contenedor_vidrio.dart';

/// Layout escritorio de Mi Espacio (panel centrado 680px).
class MiEspacioEscritorio extends StatelessWidget {
  final Widget cabecera;
  final Widget cuerpo;

  const MiEspacioEscritorio({
    super.key,
    required this.cabecera,
    required this.cuerpo,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: ContenedorVidrio(
          margin: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cabecera,
              SizedBox(height: 8),
              Expanded(child: cuerpo),
            ],
          ),
        ),
      ),
    );
  }
}