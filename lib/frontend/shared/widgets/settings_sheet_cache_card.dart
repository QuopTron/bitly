part of 'settings_sheet_new.dart';

class _CacheExplainedCard extends StatelessWidget {
  final Color glowColor;

  const _CacheExplainedCard({required this.glowColor});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cached_rounded, color: glowColor, size: r.subtitleSize),
            SizedBox(width: r.spacingS),
            Text(
              'Caché de streaming',
              style: TextStyle(
                fontSize: r.subtitleSize,
                fontWeight: FontWeight.w700,
                color: onBg,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          'Guarda temporalmente las canciones que reproduces para que las que repites suenen al instante y sin gastar datos.',
          style: TextStyle(
            fontSize: r.footerSize - 1,
            color: onBg.withValues(alpha: 0.5),
            height: 1.3,
          ),
        ),
        SizedBox(height: r.spacingS),
        SettingsCacheSection(onBg: onBg, glowColor: glowColor),
      ],
    );
  }
}

/// Card de versiones: muestra la versión actual y al tocarla abre el
/// modal [_VersionSheet] con todas las releases de GitHub.
class _VersionInfoCard extends StatelessWidget {
  final Color glowColor;
  final void Function(BuildContext) onShowVersions;

  const _VersionInfoCard({
    required this.glowColor,
    required this.onShowVersions,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);

    return GestureDetector(
      onTap: () => onShowVersions(context),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: r.spacingM,
          vertical: r.spacingM,
        ),
        decoration: BoxDecoration(
          color: onBg.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: onBg.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: r.subtitleSize + 2,
              color: glowColor,
            ),
            SizedBox(width: r.spacingS),
            Text(
              'Versiones',
              style: TextStyle(
                fontSize: r.subtitleSize,
                fontWeight: FontWeight.w600,
                color: onBg.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(width: r.spacingXS),
            Icon(
              Icons.chevron_right_rounded,
              size: r.subtitleSize,
              color: onBg.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
