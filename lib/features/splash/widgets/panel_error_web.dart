// ─────────────────────────────────────────────────────────────
// panel_error_web.dart — Panel de error del splash PARA WEB (PWA).
//
// Qué hace: explica por qué la web necesita el servidor externo
// (no está embebido como en nativo) y ofrece la app nativa como
// solución principal. El reintentar queda como secundario para
// quien acaba de encender el servidor.
//
// Se conecta con: splash_bloc + l10n + url_launcher.
// Parte del flujo: splash → error de conexión en web.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/plataforma/responsive.dart';
import '../bloc/splash_bloc.dart';
import '../bloc/splash_evento.dart';

const _urlReleases = 'https://github.com/QuopTron/bitly/releases/latest';

/// Panel de error de la PWA: explica por qué la web necesita el servidor.
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

  Future<void> _abrirDescargas() async {
    try {
      await launchUrl(
        Uri.parse(_urlReleases),
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } catch (e) { debugPrint("[Feature] $e"); }
  }

  @override
  Widget build(BuildContext context) {
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
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
              color: onBg, fontSize: r.subtitleSize + 2,
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
                fontSize: r.subtitleSize, height: 1.45,
              ),
            ),
          ),
          SizedBox(height: r.spacingL),
          _buildNativeAppBox(r, glowColor, onBg, borde),
          SizedBox(height: r.spacingM),
          TextButton(
            onPressed: () => context.read<SplashBloc>().add(const ChequearBackend()),
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

  Widget _buildNativeAppBox(Responsive r, Color glowColor, Color onBg, Color borde) {
    return Container(
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
              fontSize: r.subtitleSize, height: 1.35,
            ),
          ),
          SizedBox(height: r.spacingM),
          SizedBox(
            height: r.continueButtonHeight,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _abrirDescargas,
              icon: Icon(Icons.download_rounded, size: r.subtitleSize + 4),
              label: Text(loc.splash.webDownloadApp,
                style: const TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: glowColor,
                foregroundColor: isDark ? Colors.black : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
            ),
          ),
          SizedBox(height: r.spacingXS),
          SelectableText(
            _urlReleases,
            textAlign: TextAlign.center,
            style: TextStyle(color: onBg.withValues(alpha: 0.45), fontSize: r.footerSize),
          ),
        ],
      ),
    );
  }
}
