// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_style.dart — PART de settings_sheet_new.dart:
// el bloque "Estilo con cover" de Ajustes → Apariencia.
//
// Un solo control GENERAL de OPACIDAD: 0 es el diseño de siempre (sin color
// de carátula) y 100 el color del cover en todo. Al deslizar, el color entra
// de a poco y se ve EN VIVO, así que ya no hace falta elegir entre dos modos
// ni tocar 5 interruptores para quedar a medias. La "i" del encabezado abre
// la explicación (settings_sheet_appearance_estilo_info.dart).
//
// Detrás de "Avanzado" quedan los controles por zona
// (settings_sheet_appearance_granular.dart) para el que quiera afinar, y las
// piezas chicas del bloque (el chip) en
// settings_sheet_appearance_style_piezas.dart.
//
// Se conecta con: estilo_helper (leer y cambiar) + strings_apariencia_estilo.
// Parte del flujo: Ajustes → Apariencia → Estilo con cover.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Bloque del estilo con cover: slider general y, escondido, el avanzado.
class _StylePicker extends StatelessWidget {
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final AppLocalizations loc;

  const _StylePicker({
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    final t = loc.aparienciaEstilo;

    return ValueListenableBuilder<PreferenciasEstilo>(
      valueListenable: EstiloHelper.notifier(),
      builder:
          (context, prefs, _) => ContenedorVidrio(
            borderRadius: 16,
            borderColor: onBg.withValues(alpha: 0.08),
            bgColor: onBg.withValues(alpha: 0.03),
            padding: EdgeInsets.all(r.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Encabezado ──
                Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      color: glowColor,
                      size: r.subtitleSize,
                    ),
                    SizedBox(width: r.spacingS),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                t.estiloTitulo,
                                style: TextStyle(
                                  fontSize: r.subtitleSize,
                                  fontWeight: FontWeight.w700,
                                  color: onBg,
                                ),
                              ),
                              if (!prefs.esUniforme) ...[
                                SizedBox(width: r.spacingXS),
                                _ChipPersonalizado(
                                  texto: t.estiloPersonalizado,
                                  glowColor: glowColor,
                                  r: r,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            t.estiloAyuda,
                            style: TextStyle(
                              fontSize: r.footerSize - 2,
                              color: onBg.withValues(alpha: 0.45),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // "i": qué hace la opacidad, contado en una hoja.
                    _BotonInfoEstilo(
                      glowColor: glowColor,
                      onBg: onBg,
                      r: r,
                      onTap: () => abrirInfoEstilo(context),
                    ),
                  ],
                ),
                SizedBox(height: r.spacingM),
                // ── El control general: mueve todas las zonas a la vez ──
                _Deslizador(
                  etiqueta: t.estiloGeneral,
                  valor: prefs.general,
                  maximo: 1,
                  // 100 pasos: la barra avanza de a 1%.
                  divisiones: 100,
                  formato: _porcentaje,
                  onChanged: (v) => EstiloHelper.moverTodos(context, v),
                ),
                SizedBox(height: r.spacingS),
                // ── Cómo queda ahora: los tres paneles en vivo ──
                _PreviaEstilo(prefs: prefs, onBg: onBg, r: r, textos: t),
                SizedBox(height: r.spacingS),
                // ── Avanzado: un control por zona ──
                _SeccionGranular(
                  glowColor: glowColor,
                  onBg: onBg,
                  r: r,
                  prefs: prefs,
                  textos: t,
                ),
                if (!prefs.esNormal) ...[
                  SizedBox(height: r.spacingXS),
                  _BotonRestablecer(
                    texto: t.estiloRestablecer,
                    onPressed: () => EstiloHelper.restablecer(context),
                  ),
                ],
              ],
            ),
          ),
    );
  }
}
