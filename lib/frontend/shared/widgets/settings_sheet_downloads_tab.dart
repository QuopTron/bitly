// Parte del split de settings_sheet_new.dart — _DownloadsTab.
// Extraído del archivo original (ver git log). No editar a mano.
part of 'settings_sheet_new.dart';

class _DownloadsTab extends StatelessWidget {
  final Color glowColor;
  const _DownloadsTab({required this.glowColor});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final onBg = AppColors.onSurface(
      Theme.of(context).brightness == Brightness.dark,
    );
    final loc = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: r.spacingS),
          SettingsStorageSection(onBg: onBg, glowColor: glowColor, loc: loc),
          SizedBox(height: r.spacingS),
          _DownloadQualityCard(glowColor: glowColor),
          // No download priority section — the app handles provider
          // ordering internally.
        ],
      ),
    );
  }
}

/// Audio quality + lyrics + video settings in clean dropdown rows.
