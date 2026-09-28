// ─────────────────────────────────────────────────────────────
// settings_sheet_version_releases.dart — PART de settings_sheet_new.dart: lista de releases con la última
// destacada y sus notas.
// Se conecta con: settings_sheet_new.dart (misma library).
// Parte del flujo: Ajustes → Más (releases).
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

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
      // Esqueleto de las versiones: una tarjeta por versión, con la misma
      // altura, radio y margen que _ReleaseTile, para que al llegar la lista
      // real nada salte. Antes era una ruedita centrada que no decía qué
      // estaba trayendo.
      return ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: r.spacingM),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        itemBuilder:
            (_, _) => Container(
              margin: EdgeInsets.only(bottom: r.spacingS),
              padding: EdgeInsets.all(r.spacingM),
              decoration: BoxDecoration(
                color: onBg.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: onBg.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EsqueletoCarga(
                    ancho: r.spacingL * 3,
                    alto: r.footerSize,
                    radioBorde: 8,
                  ),
                  SizedBox(height: r.spacingXS),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.7,
                    child: EsqueletoCarga(
                      alto: r.footerSize - 2,
                      radioBorde: 6,
                    ),
                  ),
                  SizedBox(height: r.spacingS),
                  EsqueletoCarga(
                    ancho: r.spacingL * 2.5,
                    alto: r.spacingL,
                    radioBorde: 10,
                  ),
                ],
              ),
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
