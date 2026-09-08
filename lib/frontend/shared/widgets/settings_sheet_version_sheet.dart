part of 'settings_sheet_new.dart';

class _VersionSheet extends StatefulWidget {
  final Color glowColor;
  const _VersionSheet({required this.glowColor});

  @override
  State<_VersionSheet> createState() => _VersionSheetState();
}

class _VersionSheetState extends State<_VersionSheet> with _VersionSheetLoader {
  String _currentVersion = '';
  String _latestVersion = '';
  List<_ReleaseInfo> _releases = [];
  bool _loading = true;
  UpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);
    final bg = AppColors.surface(isDark);
    final glow = widget.glowColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      margin: EdgeInsets.only(top: r.spacingXL * 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            SizedBox(height: r.spacingM),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: onBg.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: r.spacingM),
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.spacingM),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: glow,
                    size: r.subtitleSize + 2,
                  ),
                  SizedBox(width: r.spacingS),
                  Text(
                    'Versiones',
                    style: TextStyle(
                      fontSize: r.subtitleSize,
                      fontWeight: FontWeight.w700,
                      color: onBg,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.spacingS),
            // Current + latest version row
            _VersionStatusCard(
              loading: _loading,
              currentVersion: _currentVersion,
              latestVersion: _latestVersion,
              glowColor: glow,
              onBg: onBg,
              r: r,
            ),
            SizedBox(height: r.spacingM),
            // Release list
            Expanded(
              child: _ReleaseList(
                releases: _releases,
                loading: _loading,
                currentVersion: _currentVersion,
                latestVersion: _latestVersion,
                glowColor: glow,
                onBg: onBg,
                r: r,
                updateInfo: _updateInfo,
                onDownloadApk: _downloadApk,
              ),
            ),
            SizedBox(height: r.bottomPadding),
          ],
        ),
      ),
    );
  }
}
