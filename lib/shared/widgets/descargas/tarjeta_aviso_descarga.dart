// ─────────────────────────────────────────────────────────────
// tarjeta_aviso_descarga.dart — Tarjeta CHICA y no invasiva con el
// aviso de una descarga: icono, título, mensaje, motivo técnico y
// hasta dos acciones. Es puramente visual: quién la muestra y qué
// hacen los botones lo decide avisos_descarga.dart.
//
// Diseño: superficie de vidrio, acento por severidad (error/ámbar/
// neutro) y ancho máximo acotado para que no tape la app ni en un
// teléfono chico ni en una pantalla grande. Sin bucles de animación.
// Las piezas (textos, cruz y botones) viven en
// tarjeta_aviso_descarga_piezas.dart.
//
// Se conecta con: colores_app (tema), responsive (escala por DPI) y
// avisos_descarga.dart.
// Parte del flujo: descargas → avisos al usuario.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../tema/colores_app.dart';
import '../../utilidades/plataforma/responsive.dart';
import '../vidrio/contenedor_vidrio.dart';

part 'tarjeta_aviso_descarga_piezas.dart';

/// Una acción de la tarjeta (texto + qué hacer). [destacada] la pinta como
/// acción principal con el acento del aviso.
class AccionAvisoDescarga {
  final String texto;
  final VoidCallback onTap;
  final bool destacada;

  const AccionAvisoDescarga(
    this.texto, {
    required this.onTap,
    this.destacada = false,
  });
}

/// Tarjeta compacta de aviso de descarga.
class TarjetaAvisoDescarga extends StatelessWidget {
  final IconData icono;
  final Color acento;
  final String titulo;
  final String? mensaje;

  /// Detalle técnico del fallo (motivo que reportó el proveedor). Se muestra
  /// chico y recortado: sirve para diagnosticar sin tapar el aviso.
  final String? motivo;

  final List<AccionAvisoDescarga> acciones;
  final VoidCallback onCerrar;

  const TarjetaAvisoDescarga({
    super.key,
    required this.icono,
    required this.acento,
    required this.titulo,
    required this.onCerrar,
    this.mensaje,
    this.motivo,
    this.acciones = const [],
  });

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final r = Responsive(context);
    final onBg = ColoresApp.enSuperficie(oscuro);

    return Material(
      // Material transparente: la tarjeta vive en el builder de MaterialApp
      // (arriba del Navigator) y sin él los textos saldrían con el
      // subrayado amarillo del DefaultTextStyle de aviso.
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: ContenedorVidrio(
          borderRadius: 16,
          borderColor: acento.withValues(alpha: 0.35),
          bgColor: ColoresApp.superficie(oscuro).withValues(alpha: 0.92),
          blurSigma: 14,
          padding: EdgeInsets.fromLTRB(
            r.spacingM,
            r.spacingS,
            r.spacingS,
            r.spacingS,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icono, size: r.footerSize + 6, color: acento),
                  SizedBox(width: r.spacingS),
                  Expanded(child: _textosAviso(this, r, oscuro, onBg)),
                  _cerrarAviso(this, r, onBg),
                ],
              ),
              if (acciones.isNotEmpty) ...[
                SizedBox(height: r.spacingXS),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final a in acciones) ...[
                      _botonAviso(this, r, a, onBg),
                      SizedBox(width: r.spacingXS),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
