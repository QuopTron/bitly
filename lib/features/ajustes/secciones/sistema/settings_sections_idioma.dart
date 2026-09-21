// ─────────────────────────────────────────────────────────────
// settings_sections_idioma.dart — Fila de idioma de Ajustes: abre el
// selector y muestra cuál está puesto.
//
// Antes este archivo traía también la sección de "restablecer datos".
// Era una herramienta de DEBUG (borra todo, incluido el estado premium,
// así que el usuario común podía terminar en el plan free sin querer) y
// no estaba montada en ninguna pestaña: se eliminó.
//
// Se conecta con: settings_sheet_appearance.dart (la monta) + l10n +
// contenedor_vidrio + idioma_helper (nombre del idioma activo).
// Parte del flujo: Ajustes (idioma).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../../../shared/utilidades/plataforma/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/utilidades/formato/comun/textos/idioma_helper.dart';
import '../../../../shared/widgets/vidrio/base/contenedor_vidrio.dart';

/// Fila de idioma: abre el selector y muestra cuál está puesto.
///
/// Sin margen propio: la pestaña de Apariencia ya le da el padding de la
/// columna, y sumarle otro la dejaba más angosta que las cards de al lado.
class SettingsLanguageSection extends StatelessWidget {
  final Color onBg;
  final Color glowColor;
  final AppLocalizations loc;
  final VoidCallback onTap;

  const SettingsLanguageSection({
    super.key,
    required this.onBg,
    required this.glowColor,
    required this.loc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final idiomaActual = nombreDeIdioma(loc, loc.locale);
    return ContenedorVidrio(
      borderRadius: 16,
      borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      padding: EdgeInsets.all(r.spacingM),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(Icons.language, color: glowColor, size: r.footerSize + 4),
            SizedBox(width: r.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.setup.languageSetting,
                    style: TextStyle(fontSize: r.subtitleSize, color: onBg),
                  ),
                  Text(
                    loc.apariencia.idiomaAyuda,
                    style: TextStyle(
                      fontSize: r.footerSize - 2,
                      color: onBg.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              idiomaActual,
              style: TextStyle(
                fontSize: r.subtitleSize,
                color: onBg.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(width: r.spacingXS),
            Icon(
              Icons.chevron_right,
              color: onBg.withValues(alpha: 0.3),
              size: r.footerSize + 2,
            ),
          ],
        ),
      ),
    );
  }
}
