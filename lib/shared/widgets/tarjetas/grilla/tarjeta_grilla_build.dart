// ─────────────────────────────────────────────────────────────
// tarjeta_grilla_build.dart — PART de tarjeta_grilla.dart: el
// `build` de la tarjeta — escucha el estilo visual y las preferencias
// (modo Spotify/clásico), mide con LayoutBuilder y delega al cuerpo
// visual, extrayendo el color dominante del cover cuando hace falta.
// Se conecta con: tarjeta_grilla.dart (misma library) + inyeccion.
// Parte del flujo: feed, búsqueda, mi espacio (tarjetas de grilla).
// ─────────────────────────────────────────────────────────────

part of 'tarjeta_grilla.dart';

/// Construye la tarjeta de grilla reaccionando al estilo y las preferencias.
Widget _construirTarjetaGrilla(TarjetaGrilla t, BuildContext context) {
  return ValueListenableBuilder<EstiloVisual>(
    valueListenable: sl<ValueNotifier<EstiloVisual>>(),
    builder: (context, estilo, _) {
      return ValueListenableBuilder<PreferenciasEstilo>(
        valueListenable: sl<ValueNotifier<PreferenciasEstilo>>(),
        builder: (context, prefs, _) {
          final r = Responsive(context);
          final esOscuro = Theme.of(context).brightness == Brightness.dark;
          final fondoFallback = ColoresApp.superficie(esOscuro);
          final fg = ColoresApp.enSuperficie(esOscuro);
          final ts = t.escalaTexto;
          final efectosPesados =
              sl<ValueNotifier<PerfilRendimiento>>().value.efectosPesados;

          final spotify =
              estilo == EstiloVisual.spotify && prefs.cardsGrilla;

          return RepaintBoundary(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (spotify && t.colorDominante == null && t.coverUrl != null) {
                  return _TarjetaGrillaColorWrapper(
                    coverUrl: t.coverUrl!,
                    builder: (colorDominante) => _cuerpoTarjeta(
                      t,
                      context,
                      constraints,
                      r,
                      esOscuro,
                      fondoFallback,
                      fg,
                      ts,
                      efectosPesados,
                      colorDominante: colorDominante,
                    ),
                  );
                }
                return _cuerpoTarjeta(
                  t,
                  context,
                  constraints,
                  r,
                  esOscuro,
                  fondoFallback,
                  fg,
                  ts,
                  efectosPesados,
                  colorDominante: spotify ? t.colorDominante : null,
                );
              },
            ),
          );
        },
      );
    },
  );
}
