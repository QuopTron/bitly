part of 'settings_sheet_new.dart';

/// Mixin con la carga de datos del sheet de versiones: versión instalada,
/// última release y la lista completa de releases de GitHub. Vive aparte
/// para mantener el archivo del widget bajo el límite de líneas.
mixin _VersionSheetLoader on State<_VersionSheet> {
  static const _releasesUrl =
      'https://api.github.com/repos/QuopTron/bitly/releases';
  static const _latestUrl =
      'https://api.github.com/repos/QuopTron/bitly/releases/latest';

  Future<void> _load() async {
    final state = this as _VersionSheetState;
    try {
      final pkg = await PackageInfo.fromPlatform();
      state._currentVersion = pkg.version;
    } catch (_) {}

    try {
      // Fetch latest for update info
      final latestResp = await http.get(
        Uri.parse(_latestUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      if (latestResp.statusCode == 200) {
        final json = jsonDecode(latestResp.body);
        final tag = json['tag_name'] as String? ?? '';
        state._latestVersion = tag.replaceFirst('v', '').trim();
      }
    } catch (_) {}

    try {
      // Fetch all releases for the version list
      final resp = await http.get(
        Uri.parse(_releasesUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        state._releases =
            list.where((r) => (r['tag_name'] as String? ?? '').isNotEmpty).map((
              r,
            ) {
              final assets = (r['assets'] as List<dynamic>?) ?? [];
              final tag = r['tag_name'] as String? ?? '';
              // Elige el asset de ESTA plataforma y arquitectura (APK del ABI
              // correcto en Android, instalador .exe en Windows). Los nombres
              // son consistentes con los que lee el sitio web del proyecto.
              final url = UpdateService.urlDescarga(
                    assets,
                    tag.replaceFirst('v', '').trim(),
                  ) ??
                  '';
              return _ReleaseInfo(
                tag: tag,
                body: (r['body'] as String? ?? ''),
                date: (r['published_at'] as String? ?? '').substring(0, 10),
                downloadUrl: url,
              );
            }).toList();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => state._loading = false);

    // Fetch update info in background for the download button
    try {
      final info = await UpdateService().checkForUpdate();
      if (mounted) setState(() => state._updateInfo = info);
    } catch (_) {}
  }
}
