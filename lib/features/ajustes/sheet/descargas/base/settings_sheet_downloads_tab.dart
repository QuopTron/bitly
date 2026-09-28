// ─────────────────────────────────────────────────────────────
// settings_sheet_downloads_tab.dart — Pestaña Descargas del sheet de Ajustes: carpeta destino, calidad de
// descarga y opciones de la cola de descargas.
//
// Se conecta con: settings_sheet_new.dart (misma library) + settings_sheet_download_quality.
// Parte del flujo: Ajustes → pestaña Descargas.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

class _DownloadsTab extends StatelessWidget {
  final Color glowColor;
  const _DownloadsTab({required this.glowColor});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final onBg = ColoresApp.enSuperficie(
      Theme.of(context).brightness == Brightness.dark,
    );
    final loc = AppLocalizations.of(context);

    // Los ajustes de Descargas se GIRAN, uno por pantalla (mismo carrusel que
    // Apariencia): así el que entra a cambiar la calidad no tiene que pasar por
    // el almacenamiento ni por el rescate.
    return CarruselAjustes(
      key: const ValueKey('carrusel-descargas'),
      etiqueta: loc.ajustes.descargas,
      glowColor: glowColor,
      onBg: onBg,
      r: r,
      paginas: [
        SettingsStorageSection(onBg: onBg, glowColor: glowColor, loc: loc),
        _DownloadQualityCard(glowColor: glowColor),
        _DownloadRescateCard(glowColor: glowColor),
        _DownloadPoolQobuzCard(glowColor: glowColor),
        // No download priority section — the app handles provider
        // ordering internally.
      ],
    );
  }
}

/// Audio quality + lyrics + video settings in clean dropdown rows.
