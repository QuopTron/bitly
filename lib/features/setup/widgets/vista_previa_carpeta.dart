// ─────────────────────────────────────────────────────────────
// vista_previa_carpeta.dart — Vista previa de la carpeta de
// descargas seleccionada en el setup: icono de carpeta animado,
// etiqueta de estado (seleccionada/sin carpeta), ruta mostrada y
// spinner mientras se elige. Se usa en el slide de almacenamiento.
// Se conecta con: slide_carpeta_almacenamiento.dart + responsive.
// Parte del flujo: setup (paso 8: carpeta de descargas).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/contenedor_vidrio.dart';

/// Vista previa de la carpeta de descargas seleccionada.
class VistaPreviaCarpeta extends StatelessWidget {
  final bool tieneRuta;
  final bool usandoPorDefecto;
  final bool eligiendo;
  final String rutaMostrada;
  final String etiquetaSeleccionada;
  final String etiquetaSinCarpeta;
  final Color onBg;
  final Color glowColor;

  const VistaPreviaCarpeta({
    super.key,
    required this.tieneRuta,
    required this.usandoPorDefecto,
    required this.eligiendo,
    required this.rutaMostrada,
    required this.etiquetaSeleccionada,
    required this.etiquetaSinCarpeta,
    required this.onBg,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingL),
      child: ContenedorVidrio(
        borderRadius: 14,
        borderColor: tieneRuta
            ? glowColor.withValues(alpha: 0.3)
            : onBg.withValues(alpha: 0.08),
        bgColor: tieneRuta
            ? glowColor.withValues(alpha: 0.04)
            : Colors.transparent,
        padding: EdgeInsets.all(r.spacingM),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.all(r.spacingS),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tieneRuta
                    ? glowColor.withValues(alpha: 0.15)
                    : onBg.withValues(alpha: 0.04),
              ),
              child: Icon(
                tieneRuta ? Icons.folder : Icons.folder_open,
                size: r.titleSize,
                color: tieneRuta
                    ? glowColor
                    : onBg.withValues(alpha: 0.3),
              ),
            ),
            SizedBox(width: r.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tieneRuta ? etiquetaSeleccionada : etiquetaSinCarpeta,
                    style: TextStyle(
                      fontSize: r.footerSize,
                      fontWeight: FontWeight.w600,
                      color: tieneRuta
                          ? glowColor
                          : onBg.withValues(alpha: 0.3),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    rutaMostrada,
                    style: TextStyle(
                      fontSize: r.footerSize - 2,
                      color: onBg.withValues(alpha: 0.4),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (eligiendo)
              SizedBox(
                width: r.footerSize,
                height: r.footerSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: glowColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}