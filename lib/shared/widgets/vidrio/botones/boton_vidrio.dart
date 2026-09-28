// ─────────────────────────────────────────────────────────────
// boton_vidrio.dart — Botón glassmorphism global: ancho completo,
// con icono/label opcionales, estado de carga (esqueleto con la
// forma del icono y de la etiqueta) y color de acento. Centraliza
// el estilo de botones de la app para no repetir
// ElevatedButton.styleFrom en cada vista.
//
// El alto, el radio, el texto y el ícono salen de las especificaciones
// del aparato (ver tema/especificaciones): en la TV el botón es alto y
// con contorno marcado —se maneja a metros—, en PC y celular más chico.
// El alto y el radio se pueden pisar por parámetro si una vista necesita
// algo puntual.
// Se conecta con: todas las vistas + especificaciones_plataforma.
// Parte del flujo: presentación (botones).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../tema/colores_app.dart';
import '../../../tema/especificaciones/especificaciones_plataforma.dart';
import '../../../widgets/esqueletos/esqueleto_carga.dart';

/// Botón glass de ancho completo con estado de carga.
class BotonVidrio extends StatelessWidget {
  final String? label;
  final Widget? icon;
  final Widget? customChild;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// Alto explícito. Si es null, lo pone el aparato (especificaciones).
  final double? height;

  /// Radio explícito. Si es null, lo pone el aparato.
  final double? borderRadius;

  final Color accent;

  const BotonVidrio({
    super.key,
    this.label,
    this.icon,
    this.customChild,
    required this.onPressed,
    this.isLoading = false,
    this.height,
    this.borderRadius,
    this.accent = ColoresApp.primario,
  });

  @override
  Widget build(BuildContext context) {
    final e = EspecificacionesPlataforma.de(context);
    final habilitado = onPressed != null && !isLoading;

    return SizedBox(
      width: double.infinity,
      height: height ?? e.altoBoton,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent.withValues(alpha: habilitado ? 0.15 : 0.04),
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? e.radioBoton),
            side: BorderSide(
              color: accent.withValues(alpha: habilitado ? 0.4 : 0.08),
              // En TV el contorno se ve grueso: es el borde del control.
              width: e.focoVisible ? e.grosorFoco - 1 : 1,
            ),
          ),
        ),
        onPressed: onPressed,
        child: customChild ?? _contenido(context, e, accent, habilitado),
      ),
    );
  }

  Widget _contenido(
    BuildContext context,
    EspecificacionesPlataforma e,
    Color accent,
    bool habilitado,
  ) {
    if (isLoading) return _cargando(e);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          icon!,
          SizedBox(width: e.grosorFoco > 0 ? 10 : 6),
        ],
        if (label != null)
          Text(
            label!,
            style: TextStyle(
              fontSize: e.textoBoton,
              fontWeight: FontWeight.w600,
              color: accent.withValues(alpha: habilitado ? 1 : 0.35),
            ),
          ),
      ],
    );
  }

  /// Mientras carga, el hueco tiene la forma de lo que VUELVE: el icono (si
  /// hay) y una barra del ancho EXACTO de la etiqueta, medida con el estilo con
  /// el que se dibuja. Antes era un cuadradito con un círculo adentro, así que
  /// el botón se encogía a `iconoBoton` y volvía a crecer al terminar.
  Widget _cargando(EspecificacionesPlataforma e) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          EsqueletoMarca(lado: e.iconoBoton),
          SizedBox(width: e.grosorFoco > 0 ? 10 : 6),
        ],
        if (label != null)
          EsqueletoEtiqueta(
            ancho: _anchoEtiqueta(e),
            alto: e.textoBoton,
            radioBorde: e.textoBoton / 3,
          ),
      ],
    );
  }

  /// Ancho que va a ocupar la etiqueta, con el estilo con el que se dibuja.
  double _anchoEtiqueta(EspecificacionesPlataforma e) {
    final pintor = TextPainter(
      text: TextSpan(
        text: label!,
        style: TextStyle(
          fontSize: e.textoBoton,
          fontWeight: FontWeight.w600,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return pintor.width;
  }
}
