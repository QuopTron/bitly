// ─────────────────────────────────────────────────────────────
// panel_error.dart — Panel de error del splash. Tiene DOS variantes
// a propósito:
//
//   · NATIVA (Android/TV/PC/macOS/iOS): mensaje corto + reintentar. El
//     backend va dentro de la app, así que un fallo es transitorio (init
//     en frío lento) y reintentar tiene sentido.
//
//   · WEB (PWA): reintentar NO alcanza, porque el servidor no está dentro
//     del navegador: alguien tiene que tenerlo encendido. Antes esta
//     pantalla decía sólo "Backend no responde" con un botón que nunca
//     iba a funcionar — un callejón sin salida para quien llegó desde el
//     sitio sin saber que la web necesita un servidor. Acá se lo explica
//     en lenguaje llano y se lo manda a la app nativa, que no necesita
//     nada instalado aparte.
//
// Se conecta con: features/splash (página + bloc) + l10n + url_launcher.
// Parte del flujo: splash (error de conexión al backend).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/responsive.dart';
import '../bloc/splash_bloc.dart';
import '../bloc/splash_estado.dart';
import '../bloc/splash_evento.dart';

/// Página de releases: de ahí se baja la app nativa (Android, Windows, macOS,
/// iOS) cuando esta versión web no aplica. Es el mismo repo que usa el
/// detector de actualizaciones.
const _urlReleases = 'https://github.com/QuopTron/bitly/releases/latest';

/// Mensaje de error + botón reintentar del splash.
class PanelError extends StatelessWidget {
  final EstadoSplash state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const PanelError({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // En web el fallo NO se arregla reintentando: se explica.
    if (kIsWeb) {
      return PanelErrorWeb(loc: loc, r: r, isDark: isDark);
    }
    final glowColor =
        isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;

    return Column(
      children: [
        SizedBox(height: r.spacingXL),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
          child: Text(
            state.error ?? loc.splash.backendNotResponding,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.65,
              ),
              fontSize: r.subtitleSize,
            ),
          ),
        ),
        SizedBox(height: r.spacingM),
        SizedBox(
          height: r.retryButtonHeight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: glowColor.withValues(alpha: 0.15),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: glowColor.withValues(alpha: 0.4)),
              ),
            ),
            onPressed:
                () => context.read<SplashBloc>().add(const ChequearBackend()),
            child: Text(
              loc.splash.retry,
              style: TextStyle(color: glowColor, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

/// Panel de error de la PWA: explica por qué la web necesita el servidor y
/// ofrece la app nativa (que no necesita nada) dejando el reintentar como
/// opción secundaria, para quien justo acaba de encender el servidor.
///
/// Es público (no `_`) a propósito: así se puede probar en un test de
/// widgets, porque `kIsWeb` no se puede activar desde el VM de tests y esta
/// pantalla sería, si no, imposible de verificar sin compilar a web.
class PanelErrorWeb extends StatelessWidget {
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const PanelErrorWeb({
    super.key,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  /// Abre la página de descargas. En web tiene que ser una pestaña nueva (el
  /// modo "externalApplication" abre el navegador del sistema, que en web no
  /// existe); si el navegador bloquea el popup, el enlace queda visible abajo
  /// para copiarlo a mano.
  Future<void> _abrirDescargas() async {
    try {
      await launchUrl(
        Uri.parse(_urlReleases),
        mode:
            kIsWeb
                ? LaunchMode.platformDefault
                : LaunchMode.externalApplication,
      );
    } catch (_) {
      // Nunca romper la pantalla de error por un link que no abrió.
    }
  }

  @override
  Widget build(BuildContext context) {
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor =
        isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
    final borde = onBg.withValues(alpha: 0.12);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Column(
        children: [
          SizedBox(height: r.spacingL),
          Icon(Icons.dns_outlined, size: 34, color: glowColor),
          SizedBox(height: r.spacingM),
          Text(
            loc.splash.webNeedsServerTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: onBg,
              fontSize: r.subtitleSize + 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: r.spacingS),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.spacingL),
            child: Text(
              loc.splash.webNeedsServerBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: onBg.withValues(alpha: 0.65),
                fontSize: r.subtitleSize,
                height: 1.45,
              ),
            ),
          ),
          SizedBox(height: r.spacingL),

          // Caja con el camino que SÍ funciona: la app nativa.
          Container(
            margin: EdgeInsets.symmetric(horizontal: r.spacingL),
            padding: EdgeInsets.all(r.spacingM + 2),
            decoration: BoxDecoration(
              color: glowColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borde),
            ),
            child: Column(
              children: [
                Text(
                  loc.splash.webUseAppHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: onBg.withValues(alpha: 0.75),
                    fontSize: r.subtitleSize,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: r.spacingM),
                SizedBox(
                  height: r.continueButtonHeight,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _abrirDescargas,
                    icon: Icon(
                      Icons.download_rounded,
                      size: r.subtitleSize + 4,
                    ),
                    label: Text(
                      loc.splash.webDownloadApp,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: glowColor,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: r.spacingXS),
                // Por si el navegador bloquea la pestaña nueva.
                SelectableText(
                  _urlReleases,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: onBg.withValues(alpha: 0.45),
                    fontSize: r.footerSize,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: r.spacingM),
          // Secundario: sólo sirve para quien acaba de encender el servidor.
          TextButton(
            onPressed:
                () => context.read<SplashBloc>().add(const ChequearBackend()),
            child: Text(
              loc.splash.retry,
              style: TextStyle(
                color: onBg.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
