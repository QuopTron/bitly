// ─────────────────────────────────────────────────────────────
// barra_navegacion_flotante.dart — Barra de navegación inferior
// flotante del LAYOUT MÓVIL (celular/tablet): 3 pestañas (Buscar,
// Inicio, Mi Espacio) con animación de selección y vidrio. Solo se
// usa en la variante móvil de la Home; el escritorio usa la barra
// lateral (barra_navegacion_lateral.dart).
// Se conecta con: home_movil.dart (navegación) + shared (vidrio,
// responsive, tema).
// Parte del flujo: Home (navegación de pestañas en celular).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/formato/apariencia_helper.dart';
import '../../../shared/utilidades/plataforma/responsive.dart';
import '../../../shared/widgets/vidrio/contenedor_vidrio.dart';
import '../../../core/modelos/usuario/catalogo_disenos_barra.dart';
import '../../../core/modelos/usuario/preferencias_apariencia.dart';
import '../../../shared/utilidades/formato/apariencia_barras_helper.dart';
import '../../../shared/utilidades/formato/apariencia_disenos_helper.dart';
import '../../../shared/utilidades/formato/apariencia_paleta_helper.dart';
import '../../../shared/widgets/barras/barra_adornada.dart';

part 'barra_navegacion_flotante_item.dart';

/// Navbar inferior flotante con vidrio (layout móvil).
class BarraNavegacionFlotante extends StatefulWidget {
  final bool isDark;
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const BarraNavegacionFlotante({
    super.key,
    required this.isDark,
    this.currentIndex = 0,
    this.onTap,
  });

  @override
  State<BarraNavegacionFlotante> createState() =>
      _BarraNavegacionFlotanteState();
}

class _BarraNavegacionFlotanteState extends State<BarraNavegacionFlotante> {
  late int _selected;

  static const _icons = [
    Icons.search_rounded,
    Icons.home_rounded,
    Icons.grid_view_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.currentIndex;
  }

  @override
  void didUpdateWidget(BarraNavegacionFlotante oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mantiene la selección sincronizada si el padre cambia currentIndex
    // (p.ej. el navbar global sobre detalles, que refleja la Home real).
    if (widget.currentIndex != oldWidget.currentIndex) {
      _selected = widget.currentIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final onBg = ColoresApp.enSuperficie(widget.isDark);
    final nav = AppLocalizations.of(context).nav;

    // Esquinas de ARRIBA del navbar: las elige el usuario en
    // Ajustes → Apariencia → Barras (por defecto 20, el diseño de fábrica).
    // Escucha el notifier para que el cambio se vea al instante.
    return ValueListenableBuilder<PreferenciasApariencia>(
      valueListenable: AparienciaHelper.notifier(),
      builder: (context, prefs, _) {
        final trazo = AparienciaBarras.trazoBorde(context);
        // Paleta del cofre (Ajustes → Apariencia → Barras): tiñe el vidrio.
        // Sin paleta queda el vidrio de siempre.
        final paleta = AparienciaBarras.paletaBarra(context, navbar: true);
        final base = ColoresApp.superficie(
          widget.isDark,
        ).withValues(alpha: 0.80);
        final bordePaleta = AparienciaPaleta.borde(
          paleta,
          esOscuro: widget.isDark,
        );
        // Adorno del cofre: esquinas (lo de siempre) u OLAS. Con olas el
        // contorno lo pinta el adorno siguiendo la ola, y la barra se lleva su
        // calcomanía si el diseño la trae.
        final adorno = AparienciaDisenos.adornoDe(context, navbar: true);
        final esOlas = adorno == AdornoBarra.olas;
        return BarraAdornada(
          adorno: adorno,
          olas: AparienciaDisenos.olasDe(context, navbar: true),
          radioArriba: prefs.radioNavbar,
          colorBorde: bordePaleta ?? onBg.withValues(alpha: 0.22),
          sticker: AparienciaDisenos.stickerDe(context, navbar: true),
          colorSticker: bordePaleta ?? onBg.withValues(alpha: 0.75),
          child: ContenedorVidrio(
            borderRadius: 0,
            blurSigma: 20,
            borderColor:
                esOlas
                    ? Colors.transparent
                    : (bordePaleta ??
                        onBg.withValues(
                          alpha: trazo.$1 == 0 ? 0.08 : trazo.$1,
                        )),
            bgColor: base,
            gradient: AparienciaPaleta.gradiente(
              paleta,
              esOscuro: widget.isDark,
              base: base,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: r.spacingM,
              vertical: r.spacingS * 0.7,
            ),
            child: Row(
              children: List.generate(
                _icons.length,
                (i) => Expanded(
                  child: _ItemNavBarra(
                    icono: _icons[i],
                    seleccionado: _selected == i,
                    r: r,
                    onBg: onBg,
                    etiqueta: nav.pestanas[i],
                    onTap: () {
                      setState(() => _selected = i);
                      widget.onTap?.call(i);
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
