part of 'settings_sheet_new.dart';

/// Botón de descarga de una release: si es la última y hay info de update
/// abre el modal de update; si no, descarga el APK directamente.
class _ReleaseDownloadButton extends StatelessWidget {
  final bool isLatest;
  final UpdateInfo? updateInfo;
  final String downloadUrl;
  final String version;
  final Color glowColor;
  final Responsive r;
  final void Function(String url, String version) onDownloadApk;

  const _ReleaseDownloadButton({
    required this.isLatest,
    required this.updateInfo,
    required this.downloadUrl,
    required this.version,
    required this.glowColor,
    required this.r,
    required this.onDownloadApk,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (isLatest && updateInfo != null) {
          showUpdateModal(context, updateInfo!);
        } else {
          onDownloadApk(downloadUrl, version);
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: r.spacingS),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [glowColor, glowColor.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            'Descargar',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: r.footerSize,
            ),
          ),
        ),
      ),
    );
  }
}
