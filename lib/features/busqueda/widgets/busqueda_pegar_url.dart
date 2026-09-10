// ─────────────────────────────────────────────────────────────
// busqueda_pegar_url.dart — Vista inicial de la búsqueda cuando no
// hay texto ni recientes: icono de link, hint de pegar una URL de
// Spotify/YouTube y badges de las fuentes soportadas.
// Se conecta con: contenedor_vidrio + l10n + responsive.
// Parte del flujo: búsqueda (estado vacío inicial).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/contenedor_vidrio.dart';

/// Vista inicial de la búsqueda: invita a pegar un link o buscar.
class VistaPegarUrl extends StatelessWidget {
  const VistaPegarUrl({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(esOscuro);
    final loc = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link,
                size: r.titleSize * 1.5, color: onBg.withValues(alpha: 0.15)),
            SizedBox(height: r.spacingM),
            Text(
              loc.setup.searchPasteHint,
              style: TextStyle(
                fontSize: r.subtitleSize,
                color: onBg.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: r.spacingM),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _badge(Icons.play_circle_fill, 'YouTube', r, onBg),
                SizedBox(width: r.spacingS),
                _badge(Icons.music_note, 'Spotify', r, onBg),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(IconData icono, String etiqueta, Responsive r, Color onBg) {
    return ContenedorVidrio(
      borderRadius: 20,
      borderColor: onBg.withValues(alpha: 0.1),
      bgColor: onBg.withValues(alpha: 0.04),
      padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingXS),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: r.footerSize + 2, color: onBg.withValues(alpha: 0.6)),
          SizedBox(width: r.spacingXS),
          Text(
            etiqueta,
            style: TextStyle(
              fontSize: r.footerSize + 2,
              color: onBg.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}