// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_diseno_piezas.dart — PART de
// settings_sheet_new.dart: las piezas del bloque "Diseño"
// (selector de borde, deslizadores, vista previa y restablecer).
//
// La vista previa dibuja ESQUELETOS con el diseño actual del usuario:
// mismo redondeo, misma separación y mismo borde que va a tener la app
// real, así no hay sorpresas al tocar un control.
//
// Se conecta con: settings_sheet_appearance_diseno.dart (misma library).
// Parte del flujo: Ajustes → Apariencia → Diseño.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Selector del borde del reproductor: sin borde / suave / marcado.
class _SelectorBorde extends StatelessWidget {
  final PreferenciasApariencia prefs;
  final StringsApariencia t;

  const _SelectorBorde({required this.prefs, required this.t});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final glow = isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.bordeTitulo,
          style: TextStyle(
            fontSize: r.footerSize,
            fontWeight: FontWeight.w600,
            color: onBg.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: r.spacingS),
        Row(
          children: [
            for (final opcion in const [
              (BordeMiniplayer.sinBorde, Icons.crop_square_rounded, ''),
              (BordeMiniplayer.suave, Icons.rounded_corner_rounded, ''),
              (BordeMiniplayer.marcado, Icons.select_all_rounded, ''),
            ])
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => AparienciaHelper.cambiarBorde(context, opcion.$1),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.spacingXS / 2),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 34,
                          decoration: BoxDecoration(
                            color: onBg.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: prefs.bordeMiniplayer == opcion.$1
                                  ? glow
                                  : onBg.withValues(alpha: 0.12),
                              width: prefs.bordeMiniplayer == opcion.$1 ? 1.6 : 1,
                            ),
                          ),
                          child: Icon(
                            opcion.$2,
                            size: 16,
                            color: prefs.bordeMiniplayer == opcion.$1
                                ? glow
                                : onBg.withValues(alpha: 0.5),
                          ),
                        ),
                        SizedBox(height: r.spacingXS / 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _nombreBorde(opcion.$1),
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: r.footerSize - 2,
                              fontWeight: prefs.bordeMiniplayer == opcion.$1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: prefs.bordeMiniplayer == opcion.$1
                                  ? glow
                                  : onBg.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _nombreBorde(BordeMiniplayer borde) {
    switch (borde) {
      case BordeMiniplayer.sinBorde:
        return t.bordeSin;
      case BordeMiniplayer.suave:
        return t.bordeSuave;
      case BordeMiniplayer.marcado:
        return t.bordeMarcado;
    }
  }
}

/// Deslizador con etiqueta y valor a la vista.
class _Deslizador extends StatelessWidget {
  final String etiqueta;
  final double valor;
  final double maximo;
  final ValueChanged<double> onChanged;

  const _Deslizador({
    required this.etiqueta,
    required this.valor,
    required this.maximo,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final glow = isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
    // Los multiplicadores se muestran con una decimal (1.0 = diseño actual)
    // y el redondeo en píxeles enteros: lo que el usuario ve es lo que aplica.
    final texto = maximo == PreferenciasApariencia.maxEspacio
        ? valor.toStringAsFixed(1)
        : '${valor.round()} px';

    return Row(
      children: [
        SizedBox(
          width: r.width * 0.24,
          child: Text(
            etiqueta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: r.footerSize, color: onBg),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: glow,
              thumbColor: glow,
              inactiveTrackColor: onBg.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: valor.clamp(0, maximo),
              max: maximo,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: r.width * 0.12,
          child: Text(
            texto,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: r.footerSize - 1,
              fontWeight: FontWeight.w700,
              color: glow,
            ),
          ),
        ),
      ],
    );
  }
}

/// Vista previa con esqueletos: el reproductor con su borde y una fila de
/// cards con el redondeo y la separación elegidos.
class _VistaPrevia extends StatelessWidget {
  final PreferenciasApariencia prefs;
  final StringsApariencia t;

  const _VistaPrevia({required this.prefs, required this.t});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final base = r.spacingXS;
    final sepX = base * prefs.espacioX;
    final sepY = base * prefs.espacioY;
    final bloque = BoxDecoration(
      color: onBg.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(prefs.radioCards),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.vistaPreviaTitulo,
          style: TextStyle(
            fontSize: r.footerSize,
            fontWeight: FontWeight.w600,
            color: onBg.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: r.spacingS),
        // Reproductor en esqueleto, con el borde elegido.
        Container(
          height: 42,
          padding: EdgeInsets.symmetric(horizontal: sepX, vertical: 6),
          decoration: BoxDecoration(
            color: onBg.withValues(alpha: 0.04),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(
              color: onBg.withValues(alpha: AparienciaHelper.trazoBorde(context).$1),
              width: AparienciaHelper.trazoBorde(context).$2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: onBg.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(prefs.radioCards * 0.4),
                ),
              ),
              SizedBox(width: sepX),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(height: 7, width: 90, decoration: bloque),
                    SizedBox(height: sepY / 2 + 2),
                    Container(height: 5, width: 60, decoration: bloque),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: sepY + 4),
        // Fila de cards en esqueleto.
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) SizedBox(width: sepX),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(decoration: bloque),
                    ),
                    SizedBox(height: sepY / 2 + 2),
                    Container(height: 6, decoration: bloque),
                  ],
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: r.spacingXS),
        Text(
          t.vistaPreviaAyuda,
          style: TextStyle(
            fontSize: r.footerSize - 2,
            color: onBg.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

/// Vuelve al diseño con el que viene la app.
class _BotonRestablecer extends StatelessWidget {
  final String texto;

  const _BotonRestablecer({required this.texto});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glow = isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
    return TextButton.icon(
      onPressed: () => AparienciaHelper.restablecer(context),
      icon: Icon(Icons.restart_alt_rounded, size: r.footerSize + 2, color: glow),
      label: Text(
        texto,
        style: TextStyle(fontSize: r.footerSize, color: glow),
      ),
    );
  }
}
