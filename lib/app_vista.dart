// ─────────────────────────────────────────────────────────────
// app_vista.dart — PART de app.dart: el árbol visual de la app raíz
// (tema dinámico → blocs globales → MaterialApp.router) y el cableado
// de la carta compartida.
//
// Se extrajo para que app.dart (arranque, rutas y deep links) no pase
// de 150 líneas: acá está solo el pintado, sin ciclo de vida.
//
// Se conecta con: app.dart (misma library) + app_contenido + tema + l10n.
// Parte del flujo: arranque (main → BitlyApp → router → splash).
// ─────────────────────────────────────────────────────────────

part of 'app.dart';

/// Raíz visual de Bitly: tema dinámico, blocs globales, router y l10n.
Widget _construirRaizApp(_BitlyAppState st) {
  return EnvoltorioColorDinamico(
    themeModeOverride: st._ajustes.themeMode.value,
    builder: (temaClaro, temaOscuro, modoTema) {
      return MultiBlocProvider(
        providers: [
          BlocProvider<SplashBloc>(create: (_) => di.sl<SplashBloc>()),
          BlocProvider<SetupBloc>(create: (_) => di.sl<SetupBloc>()),
        ],
        child: MaterialApp.router(
          title: 'Bitly',
          debugShowCheckedModeBanner: false,
          theme: temaClaro,
          darkTheme: temaOscuro,
          themeMode: modoTema,
          locale: st._ajustes.locale.value,
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: st._router,
          builder: (context, hijo) => construirContenidoApp(
            context: context,
            hijo: hijo,
            // Mientras la app no salió del splash la carta no se pinta; el
            // enlace sigue guardado y aparece apenas entra al contenido.
            linkCompartido: st._appLista ? st._linkCompartido : null,
            onDismiss: st._descartarCompartido,
            onPlay: st.reproducirCompartido,
            onAgregar: st.agregarCompartidoALaCola,
            hayReproduccion: st.hayReproduccion,
          ),
        ),
      );
    },
  );
}
