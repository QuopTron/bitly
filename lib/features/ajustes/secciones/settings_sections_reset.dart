// ─────────────────────────────────────────────────────────────
// settings_sections_reset.dart — Secciones de reset de datos y selector de idioma de Ajustes.
// Se conecta con: settings_sections.dart (las usa) + l10n + contenedor_vidrio.
// Parte del flujo: Ajustes (reset e idioma).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../../shared/utilidades/plataforma/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/vidrio/contenedor_vidrio.dart';


class SettingsResetSection extends StatelessWidget {
  final Color onBg;
  final Color glowColor;
  final AppLocalizations loc;
  final VoidCallback onTap;
  final bool resetting;

  const SettingsResetSection({
    super.key,
    required this.onBg,
    required this.glowColor,
    required this.loc,
    required this.onTap,
    this.resetting = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return ContenedorVidrio(
      borderRadius: 16, borderColor: Colors.redAccent.withValues(alpha: 0.25),
      bgColor: Colors.redAccent.withValues(alpha: 0.04),
      margin: EdgeInsets.symmetric(horizontal: r.spacingM),
      padding: EdgeInsets.all(r.spacingM),
      child: InkWell(
        onTap: resetting ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(children: [
          Icon(
            resetting ? Icons.hourglass_top : Icons.delete_sweep,
            color: resetting ? glowColor : Colors.redAccent,
            size: r.footerSize + 4,
          ),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                resetting ? loc.setup.completingSetup : loc.setup.resetData,
                style: TextStyle(
                  fontSize: r.subtitleSize,
                  fontWeight: FontWeight.w600,
                  color: resetting ? glowColor : Colors.redAccent,
                ),
              ),
              Text(
                resetting ? '' : loc.setup.resetData,
                style: TextStyle(fontSize: r.footerSize - 2, color: Colors.redAccent.withValues(alpha: 0.5)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          if (resetting)
            SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: glowColor),
            )
          else
            Icon(Icons.chevron_right, color: Colors.redAccent.withValues(alpha: 0.5), size: r.footerSize + 2),
        ]),
      ),
    );
  }
}

class SettingsLanguageSection extends StatelessWidget {
  final Color onBg;
  final Color glowColor;
  final AppLocalizations loc;
  final VoidCallback onTap;
  final String currentLanguage;

  const SettingsLanguageSection({
    super.key,
    required this.onBg,
    required this.glowColor,
    required this.loc,
    required this.onTap,
    this.currentLanguage = 'Español',
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return ContenedorVidrio(
      borderRadius: 16, borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      margin: EdgeInsets.symmetric(horizontal: r.spacingM),
      padding: EdgeInsets.all(r.spacingM),
      child: InkWell(
        onTap: onTap,
        child: Row(children: [
          Icon(Icons.language, color: glowColor, size: r.footerSize + 4),
          SizedBox(width: r.spacingS),
          Expanded(child: Text(loc.setup.languageSetting, style: TextStyle(fontSize: r.subtitleSize, color: onBg))),
          Text(currentLanguage, style: TextStyle(fontSize: r.subtitleSize, color: onBg.withValues(alpha: 0.5))),
          SizedBox(width: r.spacingXS),
          Icon(Icons.chevron_right, color: onBg.withValues(alpha: 0.3), size: r.footerSize + 2),
        ]),
      ),
    );
  }
}
