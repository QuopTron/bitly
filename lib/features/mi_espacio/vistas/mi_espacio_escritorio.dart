// ─────────────────────────────────────────────────────────────
// mi_espacio_escritorio.dart — Variante escritorio de Mi Espacio:
// panel de contenido centrado (ancho máximo 680px) sobre el fondo
// de la app, con la cabecera (perfil + banner) y el cuerpo
// (pestañas + contenido) ya armados desde la página.
// Se conecta con: pagina_mi_espacio.dart (padre).
// Parte del flujo: Home → Mi Espacio (escritorio/web).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../shared/tema/especificaciones/especificaciones_plataforma.dart';
import '../../../shared/utilidades/plataforma/responsive.dart';
import '../../../shared/widgets/vidrio/base/contenedor_vidrio.dart';

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
    // El panel de escritorio se mide con el aparato: en una tele el ancho
    // máximo y el aire crecen, así no queda una columna angosta al medio.
    final r = Responsive(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.sobre(1120, 1400)),
        child: ContenedorVidrio(
          margin: EdgeInsets.all(r.sobre(16, 26)),
          borderRadius: EspecificacionesPlataforma.de(context).radioHoja,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cabecera,
              SizedBox(height: r.spacingS),
              Expanded(child: cuerpo),
            ],
          ),
        ),
      ),
    );
  }
}
