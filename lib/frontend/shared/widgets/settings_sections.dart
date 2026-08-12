import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import 'glass_container.dart';

class SettingsProfileSection extends StatelessWidget {
  final String username;
  final Color onBg;
  final Color glowColor;
  final AppLocalizations loc;

  const SettingsProfileSection({
    super.key,
    required this.username,
    required this.onBg,
    required this.glowColor,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return GlassContainer(
      borderRadius: 16, borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      margin: EdgeInsets.symmetric(horizontal: r.spacingM),
      padding: EdgeInsets.all(r.spacingM),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [glowColor, glowColor.withValues(alpha: 0.5)]),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?',
            style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.bold, color: Colors.white))),
        ),
        SizedBox(width: r.spacingS),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(username.isNotEmpty ? username : loc.setup.miSpaceGuest,
            style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: onBg)),
          Text(loc.setup.premiumStatus, style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.4))),
        ])),
      ]),
    );
  }
}

class SettingsThemeSection extends StatelessWidget {
  final bool isDark;
  final Color onBg;
  final Color glowColor;
  final AppLocalizations loc;
  final VoidCallback onToggle;

  const SettingsThemeSection({
    super.key,
    required this.isDark,
    required this.onBg,
    required this.glowColor,
    required this.loc,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return GlassContainer(
      borderRadius: 16, borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      margin: EdgeInsets.symmetric(horizontal: r.spacingM),
      padding: EdgeInsets.all(r.spacingM),
      child: Row(children: [
        Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: glowColor, size: r.footerSize + 4),
        SizedBox(width: r.spacingS),
        Expanded(child: Text(loc.setup.theme, style: TextStyle(fontSize: r.subtitleSize, color: onBg))),
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingXS),
            decoration: BoxDecoration(
              color: glowColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: glowColor.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: r.footerSize, color: glowColor),
              SizedBox(width: 4),
              Text(isDark ? loc.setup.lightMode : loc.setup.darkMode,
                style: TextStyle(fontSize: r.footerSize - 1, color: glowColor, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ]),
    );
  }
}

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
    return GlassContainer(
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
                resetting ? '' : '⚠ ${loc.setup.resetData}',
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
    return GlassContainer(
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


