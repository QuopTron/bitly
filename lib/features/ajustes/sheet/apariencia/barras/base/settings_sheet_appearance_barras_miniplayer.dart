// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_barras_miniplayer.dart — PART de
// settings_sheet_new.dart: los presets del MINIPLAYER dentro de la tarjeta
// "Barras" (Ajustes → Apariencia → Barras, con el miniplayer seleccionado).
//
// Van acá y no en una tarjeta nueva a propósito: las esquinas y las olas del
// miniplayer ya se ajustan en Barras, y repartir lo del mismo componente en dos
// lugares es la forma más rápida de que el usuario no encuentre nada.
//
// Qué resuelve: hasta ahora el miniplayer tenía UNA sola forma por aparato y no
// se podía tocar. El TAMAÑO agranda carátula y botones; la FORMA decide si la
// barra se pega al canto o queda como tarjeta flotante.
//
// Toda la cuenta vive en miniplayer_geometria.dart (con sus acotadas): acá sólo
// se elige el preset.
//
// Se conecta con: miniplayer_geometria.dart (las reglas) +
// preferencias_apariencia.dart (dónde se guarda) + el chip compartido.
// Parte del flujo: Ajustes → Apariencia → Barras → Miniplayer.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Presets del miniplayer: tamaño y forma.
class _MiniplayerPresets extends StatelessWidget {
  final PreferenciasApariencia prefs;
  final StringsAparienciaBarras t;
  final Responsive r;
  final Color onBg;
  final Color glowColor;

  const _MiniplayerPresets({
    required this.prefs,
    required this.t,
    required this.r,
    required this.onBg,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    // A qué equivale `auto` en ESTE aparato. Va en la etiqueta porque si no el
    // usuario elige "Automático" en el celular, no ve ningún cambio y parece
    // que el control no funciona.
    final autoFlota = usarLayoutTv(context) || usarLayoutEscritorio(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.spacingS),
        _eje(
          rotulo: t.tamano,
          ayuda: t.ayudaTamano,
          chips: [
            for (final v in TamanoMiniplayer.values)
              _chip(
                context,
                texto: _nombreTamano(v),
                seleccionado: prefs.tamanoMiniplayer == v,
                onTap: () => prefs.copiarCon(tamanoMiniplayer: v),
              ),
          ],
        ),
        SizedBox(height: r.spacingS),
        _eje(
          rotulo: t.forma,
          ayuda: t.ayudaForma,
          chips: [
            for (final v in FormaMiniplayer.values)
              _chip(
                context,
                texto: _nombreForma(v, autoFlota),
                seleccionado: prefs.formaMiniplayer == v,
                onTap: () => prefs.copiarCon(formaMiniplayer: v),
              ),
          ],
        ),
        SizedBox(height: r.spacingS),
        _eje(
          rotulo: t.ancho,
          ayuda: t.ayudaAncho,
          chips: [
            for (final v in AnchoMiniplayer.values)
              _chip(
                context,
                texto: _nombreAncho(v),
                seleccionado: prefs.anchoMiniplayer == v,
                onTap: () => prefs.copiarCon(anchoMiniplayer: v),
              ),
          ],
        ),
      ],
    );
  }

  /// Un chip que guarda el preset al tocarlo.
  Widget _chip(
    BuildContext context, {
    required String texto,
    required bool seleccionado,
    required PreferenciasApariencia Function() onTap,
  }) => _ChipOpcion(
    texto: texto,
    seleccionado: seleccionado,
    r: r,
    onBg: onBg,
    glowColor: glowColor,
    onTap: () {
      Haptico.tap();
      AparienciaHelper.cambiar(context, onTap());
    },
  );

  /// Un eje: rótulo, sus chips y la ayuda.
  Widget _eje({
    required String rotulo,
    required String ayuda,
    required List<Widget> chips,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: TextStyle(
            fontSize: r.footerSize,
            fontWeight: FontWeight.w600,
            color: onBg.withValues(alpha: 0.85),
          ),
        ),
        SizedBox(height: r.spacingXS),
        Wrap(spacing: r.spacingXS, runSpacing: r.spacingXS, children: chips),
        _AyudaControl(texto: ayuda, r: r, onBg: onBg),
      ],
    );
  }

  /// Nombre del preset de tamaño (los textos viven en las cadenas).
  String _nombreTamano(TamanoMiniplayer v) {
    switch (v) {
      case TamanoMiniplayer.compacto:
        return t.compacto;
      case TamanoMiniplayer.normal:
        return t.normal;
      case TamanoMiniplayer.grande:
        return t.grande;
    }
  }

  /// Nombre de la forma. `auto` dice a qué equivale en este aparato.
  String _nombreForma(FormaMiniplayer v, bool autoFlota) {
    switch (v) {
      case FormaMiniplayer.auto:
        return '${t.formaAuto} · ${autoFlota ? t.formaFlotante : t.formaPegado}';
      case FormaMiniplayer.pegado:
        return t.formaPegado;
      case FormaMiniplayer.flotante:
        return t.formaFlotante;
    }
  }

  /// Nombre del preset de ancho. `auto` aclara que sólo cambia en pantallas
  /// enormes: si no, el usuario cree que el control no hace nada.
  String _nombreAncho(AnchoMiniplayer v) {
    switch (v) {
      // De fábrica sigue siendo ancho completo; recién acota cuando la
      // pantalla es enorme. Decirlo evita que parezca que no hace nada.
      case AnchoMiniplayer.auto:
        return '${t.anchoAuto} · ${t.anchoCompleto}';
      case AnchoMiniplayer.contenido:
        return t.anchoContenido;
      case AnchoMiniplayer.completo:
        return t.anchoCompleto;
    }
  }
}
