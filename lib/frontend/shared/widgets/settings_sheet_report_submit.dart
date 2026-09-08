part of 'settings_sheet_new.dart';

/// Crea un issue de GitHub en QuopTron/bitly con el token configurado.
/// Devuelve true cuando el issue se creó correctamente.
Future<bool> submitReport({
  required BuildContext context,
  required bool isBug,
  required String title,
  required String body,
}) async {
  if (title.isEmpty) return false;
  try {
    final pkg = await PackageInfo.fromPlatform();
    final appVersion = 'v${pkg.version}';
    final prefix = isBug ? '[Bug]' : '[Sugerencia]';
    final issueBody = [
      body,
      '',
      '---',
      'App: Bitly $appVersion',
      'Plataforma: ${Platform.isAndroid
          ? 'Android'
          : Platform.isIOS
          ? 'iOS'
          : Platform.isLinux
          ? 'Linux'
          : Platform.isWindows
          ? 'Windows'
          : Platform.isMacOS
          ? 'macOS'
          : 'desktop'}',
    ].join('\n');
    final resp = await http.post(
      Uri.parse('https://api.github.com/repos/QuopTron/bitly/issues'),
      headers: {
        'Authorization': 'token $githubToken',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'title': '$prefix $title', 'body': issueBody}),
    );
    return resp.statusCode == 201 || resp.statusCode == 200;
  } catch (_) {
    return false;
  }
}
