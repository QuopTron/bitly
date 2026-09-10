part of 'settings_sheet_new.dart';

/// Tile de una release: badge INSTALADA/NUEVA, versión, fecha, changelog
/// recortado y botón de descarga (si hay APK y no es la instalada).
class _ReleaseTile extends StatelessWidget {
  final _ReleaseInfo release;
  final String currentVersion;
  final String latestVersion;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final UpdateInfo? updateInfo;
  final void Function(String url, String version) onDownloadApk;

  const _ReleaseTile({
    required this.release,
    required this.currentVersion,
    required this.latestVersion,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.updateInfo,
    required this.onDownloadApk,
  });

  @override
  Widget build(BuildContext context) {
    final glow = glowColor;
    final tagClean = release.tag.replaceFirst('v', '').trim();
    final isCurrent = tagClean == currentVersion;
    final isLatest = tagClean == latestVersion;
    final rel = release;

    return Container(
      margin: EdgeInsets.only(bottom: r.spacingS),
      padding: EdgeInsets.all(r.spacingM),
      decoration: BoxDecoration(
        color:
            isCurrent
                ? glow.withValues(alpha: 0.12)
                : onBg.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isCurrent
                  ? glow.withValues(alpha: 0.4)
                  : isLatest
                  ? glow.withValues(alpha: 0.2)
                  : onBg.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isCurrent)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: glow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'INSTALADA',
                    style: TextStyle(
                      fontSize: r.footerSize - 3,
                      color: glow,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else if (isLatest && tagClean != currentVersion)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: glow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'NUEVA',
                    style: TextStyle(
                      fontSize: r.footerSize - 3,
                      color: glow,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              SizedBox(width: r.spacingS),
              Text(
                'v$tagClean',
                style: TextStyle(
                  fontSize: r.subtitleSize - 1,
                  fontWeight: FontWeight.w700,
                  color: onBg,
                ),
              ),
              Spacer(),
              Text(
                rel.date,
                style: TextStyle(
                  fontSize: r.footerSize - 3,
                  color: onBg.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          if (rel.body.isNotEmpty) ...[
            SizedBox(height: r.spacingXS),
            Text(
              _stripChangelog(rel.body),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: r.footerSize - 1,
                color: onBg.withValues(alpha: 0.5),
                height: 1.3,
              ),
            ),
          ],
          // Download button for any version that has an APK and is not current
          if (!isCurrent && rel.downloadUrl.isNotEmpty) ...[
            SizedBox(height: r.spacingS),
            _ReleaseDownloadButton(
              isLatest: isLatest,
              updateInfo: updateInfo,
              downloadUrl: rel.downloadUrl,
              version: tagClean,
              glowColor: glow,
              r: r,
              onDownloadApk: onDownloadApk,
            ),
          ],
        ],
      ),
    );
  }
}
