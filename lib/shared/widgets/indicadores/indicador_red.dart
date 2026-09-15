// ─────────────────────────────────────────────────────────────
// indicador_red.dart — Indicador global de red de la barra superior.
// Escucha ServicioCalidadRed y dibuja una píldora de vidrio con el
// icono del tipo de conexión (WiFi / móvil / ethernet / sin red) y un
// medidor de 3 barras que refleja el nivel medido. Al tocarla abre la
// hoja de detalle (part indicador_red_hoja.dart).
// Diseño: monocromo como el resto de la app; solo los estados
// problemáticos usan los colores de estado de ColoresApp.
// Se conecta con: servicio_calidad_red + l10n (StringsRed) +
// ColoresApp + Responsive + contenedor_vidrio.
// Parte del flujo: Home → barra superior (junto al título).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/plataforma/red/servicio_calidad_red.dart';
import '../../../l10n/app_localizations.dart';
import '../../tema/colores_app.dart';
import '../../utilidades/plataforma/responsive.dart';
import '../vidrio/contenedor_vidrio.dart';

part 'indicador_red_hoja_piezas.dart';
part 'indicador_red_hoja.dart';
part 'indicador_red_etiqueta.dart';
part 'indicador_red_barras.dart';

/// Píldora compacta del estado de red. [onBg] es el color de contenido
/// del tema actual (blanco en oscuro, negro en claro).
class IndicadorRed extends StatelessWidget {
  final Color onBg;

  /// True en escritorio: muestra también la etiqueta del nivel.
  final bool conEtiqueta;

  const IndicadorRed({super.key, required this.onBg, this.conEtiqueta = false});

  @override
  Widget build(BuildContext context) {
    final servicio = ServicioCalidadRed.instancia;
    final loc = AppLocalizations.of(context);
    final r = Responsive(context);

    return ValueListenableBuilder<EstadoCalidadRed>(
      valueListenable: servicio.estado,
      builder: (context, estado, _) {
        final etiqueta = etiquetaNivelRed(loc, estado.nivel);
        return Semantics(
          button: true,
          label: '${loc.red.a11yOpen}. $etiqueta',
          child: GestureDetector(
            onTap: () => mostrarHojaEstadoRed(context),
            child: ContenedorVidrio(
              borderRadius: 20,
              borderColor: onBg.withValues(alpha: 0.08),
              bgColor: onBg.withValues(alpha: 0.03),
              padding: EdgeInsets.symmetric(
                horizontal: r.spacingS,
                vertical: r.val(5, 3, 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconoTipoRed(estado),
                    size: r.footerSize + 2,
                    color: colorNivelRed(estado.nivel, estado.tipo, onBg),
                  ),
                  SizedBox(width: r.spacingXS),
                  BarrasCalidadRed(
                    nivel: estado.nivel,
                    midiendo: estado.midiendo,
                    onBg: onBg,
                  ),
                  if (conEtiqueta) ...[
                    SizedBox(width: r.spacingXS),
                    Text(
                      etiqueta,
                      style: TextStyle(
                        fontSize: r.footerSize - 1,
                        fontWeight: FontWeight.w600,
                        color: onBg.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Icono del tipo de conexión actual.
IconData iconoTipoRed(EstadoCalidadRed estado) {
  switch (estado.tipo) {
    case TipoRed.wifi:
      return estado.nivel == NivelRed.mala ? Icons.wifi_1_bar : Icons.wifi;
    case TipoRed.movil:
      return Icons.signal_cellular_alt;
    case TipoRed.ethernet:
      return Icons.lan;
    case TipoRed.otra:
      return Icons.public;
    case TipoRed.ninguna:
      return Icons.wifi_off;
  }
}

/// Color del indicador: el color del tema salvo en los estados
/// problemáticos, donde se usan los colores de estado de la paleta
/// (rojo sin conexión, ámbar red lenta).
Color colorNivelRed(NivelRed nivel, TipoRed tipo, Color onBg) {
  switch (nivel) {
    case NivelRed.mala:
      return tipo == TipoRed.ninguna
          ? ColoresApp.error
          : ColoresApp.advertencia;
    case NivelRed.regular:
      return ColoresApp.advertencia;
    case NivelRed.buena:
    case NivelRed.excelente:
    case NivelRed.desconocido:
      return onBg.withValues(alpha: nivel == NivelRed.excelente ? 1 : 0.8);
  }
}

/// Etiqueta legible del nivel de calidad para el locale actual.
String etiquetaNivelRed(AppLocalizations loc, NivelRed nivel) {
  switch (nivel) {
    case NivelRed.excelente:
      return loc.red.excellent;
    case NivelRed.buena:
      return loc.red.good;
    case NivelRed.regular:
      return loc.red.fair;
    case NivelRed.mala:
      return loc.red.poor;
    case NivelRed.desconocido:
      return loc.red.measuring;
  }
}
