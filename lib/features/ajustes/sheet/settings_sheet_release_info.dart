// Parte del split de settings_sheet_new.dart — _ReleaseInfo.
// Extraído del archivo original (ver git log). No editar a mano.
part of 'settings_sheet_new.dart';

class _ReleaseInfo {
  final String tag;
  final String body;
  final String date;
  final String downloadUrl;
  const _ReleaseInfo({
    required this.tag,
    required this.body,
    required this.date,
    this.downloadUrl = '',
  });
}
