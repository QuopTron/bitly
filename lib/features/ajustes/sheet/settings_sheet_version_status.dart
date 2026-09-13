part of 'settings_sheet_new.dart';

/// Card con la versión instalada y la última disponible en GitHub.
/// Muestra un spinner mientras carga y la última versión solo si existe.
class _VersionStatusCard extends StatelessWidget {
  final bool loading;
  final String currentVersion;
  final String latestVersion;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _VersionStatusCard({
    required this.loading,
    required this.currentVersion,
    required this.latestVersion,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final glow = glowColor;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingM),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(r.spacingM),
        decoration: BoxDecoration(
          color: onBg.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: glow.withValues(alpha: 0.2)),
        ),
        child:
            loading
                ? Center(
                  child: CircularProgressIndicator(strokeWidth: 2, color: glow),
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.phone_android_rounded,
                          size: r.footerSize + 2,
                          color: onBg.withValues(alpha: 0.6),
                        ),
                        SizedBox(width: r.spacingS),
                        Text(
                          'Instalada',
                          style: TextStyle(
                            fontSize: r.footerSize,
                            color: onBg.withValues(alpha: 0.5),
                          ),
                        ),
                        Spacer(),
                        Text(
                          'v$currentVersion',
                          style: TextStyle(
                            fontSize: r.subtitleSize,
                            fontWeight: FontWeight.w700,
                            color: onBg,
                          ),
                        ),
                      ],
                    ),
                    if (latestVersion.isNotEmpty) ...[
                      SizedBox(height: r.spacingS),
                      Divider(height: 1, color: onBg.withValues(alpha: 0.08)),
                      SizedBox(height: r.spacingS),
                      Row(
                        children: [
                          Icon(
                            Icons.cloud_download_rounded,
                            size: r.footerSize + 2,
                            color: glow.withValues(alpha: 0.8),
                          ),
                          SizedBox(width: r.spacingS),
                          Text(
                            'Última',
                            style: TextStyle(
                              fontSize: r.footerSize,
                              color: onBg.withValues(alpha: 0.5),
                            ),
                          ),
                          Spacer(),
                          Text(
                            'v$latestVersion',
                            style: TextStyle(
                              fontSize: r.subtitleSize,
                              fontWeight: FontWeight.w700,
                              color: glow,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
      ),
    );
  }
}
