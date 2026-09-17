// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_diseno.dart — PART de settings_sheet_new.dart:
// bloque "Diseño" de la pestaña Apariencia.
//
// Qué deja tocar: el borde del reproductor (navbar/miniplayer), la
// separación entre cards de las grillas (X e Y) y el redondeo de las
// cards. Todo se aplica AL INSTANTE porque lee el notifier global, y se
// guarda al tocarlo.
//
// Abajo va la vista previa: esqueletos con el diseño ACTUAL del usuario
// (mismo redondeo, misma separación y mismo borde), que es exactamente
// el que trae la app hasta que el usuario cambie algo.
//
// Se conecta con: settings_sheet_new.dart (misma library) +
// apariencia_helper + preferencias_apariencia.
// Parte del flujo: Ajustes → Apariencia → Diseño.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Bloque de diseño personalizable con su vista previa.
class _DisenoCard extends StatelessWidget {
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final AppLocalizations loc;

  const _DisenoCard({
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    final t = loc.apariencia;
    return ValueListenableBuilder<PreferenciasApariencia>(
      valueListenable: AparienciaHelper.notifier(),
      builder: (context, prefs, _) => ContenedorVidrio(
        borderRadius: 16,
        borderColor: onBg.withValues(alpha: 0.08),
        bgColor: onBg.withValues(alpha: 0.03),
        padding: EdgeInsets.all(r.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo(t.disenoTitulo, t.disenoAyuda),
            SizedBox(height: r.spacingS),
            _SelectorBorde(prefs: prefs, t: t),
            SizedBox(height: r.spacingM),
            _Deslizador(
              etiqueta: t.separacionX,
              valor: prefs.espacioX,
              maximo: PreferenciasApariencia.maxEspacio,
              onChanged: (v) => AparienciaHelper.cambiarEspacioX(context, v),
            ),
            _Deslizador(
              etiqueta: t.separacionY,
              valor: prefs.espacioY,
              maximo: PreferenciasApariencia.maxEspacio,
              onChanged: (v) => AparienciaHelper.cambiarEspacioY(context, v),
            ),
            _Deslizador(
              etiqueta: t.radioTitulo,
              valor: prefs.radioCards,
              maximo: PreferenciasApariencia.maxRadio,
              onChanged: (v) => AparienciaHelper.cambiarRadio(context, v),
            ),
            Text(
              t.separacionAyuda,
              style: TextStyle(
                fontSize: r.footerSize - 2,
                color: onBg.withValues(alpha: 0.4),
              ),
            ),
            SizedBox(height: r.spacingM),
            _VistaPrevia(prefs: prefs, t: t),
            if (!prefs.esDeFabrica) ...[
              SizedBox(height: r.spacingS),
              _BotonRestablecer(texto: t.restablecer),
            ],
          ],
        ),
      ),
    );
  }

  Widget _titulo(String titulo, String ayuda) => Row(
        children: [
          Icon(Icons.tune_rounded, color: glowColor, size: r.subtitleSize),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: r.subtitleSize,
                    fontWeight: FontWeight.w700,
                    color: onBg,
                  ),
                ),
                Text(
                  ayuda,
                  style: TextStyle(
                    fontSize: r.footerSize - 2,
                    color: onBg.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
