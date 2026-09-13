part of 'settings_sheet_new.dart';

/// Lista de releases de GitHub dentro del sheet de versiones.
/// Muestra un spinner mientras carga, un mensaje vacío si no hay releases
/// y la lista de [_ReleaseTile] una por versión publicada.
class _ReleaseList extends StatelessWidget {
  final List<_ReleaseInfo> releases;
  final bool loading;
  final String currentVersion;
  final String latestVersion;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final UpdateInfo? updateInfo;
  final void Function(String url, String version) onDownloadApk;

  const _ReleaseList({
    required this.releases,
    required this.loading,
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

    if (loading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: glow.withValues(alpha: 0.5),
        ),
      );
    }
    if (releases.isEmpty) {
      return Center(
        child: Text(
          'No se encontraron versiones',
          style: TextStyle(
            color: onBg.withValues(alpha: 0.4),
            fontSize: r.footerSize,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: r.spacingM),
      itemCount: releases.length,
      itemBuilder: (ctx, i) {
        final rel = releases[i];
        return _ReleaseTile(
          release: rel,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          glowColor: glow,
          onBg: onBg,
          r: r,
          updateInfo: updateInfo,
          onDownloadApk: onDownloadApk,
        );
      },
    );
  }
}
