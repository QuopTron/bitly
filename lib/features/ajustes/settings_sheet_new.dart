import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../shared/utilidades/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/tema/colores_app.dart';
import '../../core/modelos/ajustes_descarga.dart';
import '../../core/modelos/estado_premium.dart';
import '../../core/cache/reproduccion_cache.dart';
import '../../core/cache/reproduccion_stats.dart';
import '../../core/cache/estado_cola.dart';
import '../../core/cache/cache_premium.dart';
import '../../core/cache/cache_ajustes.dart';
import '../../estado/cubit_like.dart';
import '../../core/backend_go/contrato_backend.dart';
import '../../estado/cubit_reproductor.dart';
import '../../estado/cubit_cola.dart';
import '../../core/servicios/servicio_oauth_youtube.dart';
import '../../config/secretos.dart';
import '../../app/inyeccion.dart';
import '../../shared/widgets/contenedor_vidrio.dart';
import 'settings_sections.dart';
import 'settings_cache_section.dart';
import 'settings_performance_section.dart';
import 'settings_stats.dart';
import 'update_modal.dart';
import '../../shared/utilidades/paleta_portada.dart';
import '../../shared/widgets/imagen_portada.dart' show imagenDesdeUrl;
import '../../core/modelos/perfil_rendimiento.dart';
part 'settings_sheet_background.dart';
part 'settings_sheet_profile_header.dart';
part 'settings_sheet_appearance.dart';
part 'settings_sheet_appearance_tile.dart';
part 'settings_sheet_downloads_tab.dart';
part 'settings_sheet_performance.dart';
part 'settings_sheet_release_info.dart';
part 'settings_sheet_bubble_tab.dart';
part 'settings_sheet_stats.dart';
part 'settings_sheet_stats_sections.dart';
part 'settings_sheet_stats_top_section.dart';
part 'settings_sheet_stats_widgets.dart';
part 'settings_sheet_trial_chip.dart';
part 'settings_sheet_download_quality.dart';
part 'settings_sheet_download_rows.dart';
part 'settings_sheet_download_picker.dart';
part 'settings_sheet_download_labels.dart';
part 'settings_sheet_download_quality_helpers.dart';

part 'settings_sheet_more_tab.dart';
part 'settings_sheet_google_tile.dart';
part 'settings_sheet_google_content.dart';
part 'settings_sheet_google_connect.dart';
part 'settings_sheet_more_premium.dart';
part 'settings_sheet_premium_activation_card.dart';
part 'settings_sheet_premium_sheet.dart';
part 'settings_sheet_premium_widgets.dart';
part 'settings_sheet_premium_form.dart';
part 'settings_sheet_more_report.dart';
part 'settings_sheet_report_dialog.dart';
part 'settings_sheet_report_title.dart';
part 'settings_sheet_report_submit.dart';
part 'settings_sheet_report_chip.dart';
part 'settings_sheet_report_type_toggle.dart';
part 'settings_sheet_more_cards.dart';
part 'settings_sheet_cache_card.dart';
part 'settings_sheet_version_sheet.dart';
part 'settings_sheet_version_releases.dart';
part 'settings_sheet_sheet_state.dart';
part 'settings_sheet_version_tile.dart';
part 'settings_sheet_version_download_button.dart';
part 'settings_sheet_version_status.dart';
part 'settings_sheet_version_download.dart';
part 'settings_sheet_version_load.dart';
part 'settings_sheet_stats_top_tile.dart';
part 'settings_sheet_stats_helpers.dart';
part 'settings_sheet_sheet_build.dart';
part 'settings_sheet_sheet_widgets.dart';

// Tab order: Apariencia first (live color), then Descargas, Rendimiento, Más.
// Top-level para que los part files (p.ej. _BubbleTab) puedan leerlo.
final List<({IconData icon, String label})> _bubbleTabs = [
  (icon: Icons.palette_outlined, label: 'Apariencia'),
  (icon: Icons.download_rounded, label: 'Descargas'),
  (icon: Icons.speed_rounded, label: 'Rendimiento'),
  (icon: Icons.more_horiz, label: 'Más'),
];

/// Reacts to the current queue + playback: when a track is loaded (and has a
/// cover) the sheet gets tinted with the cover's dominant color via a blurred
/// ambient backdrop; when playback stops / queue empties it fades back to the
/// theme's default surface. Colors animate so the transition is smooth.
void showSettingsSheet(
  BuildContext context, {
  required String username,
  required bool isDark,
  required ValueChanged<bool> onThemeChanged,
  required VoidCallback onLanguageChanged,
  String likedCount = '0',
  String downloadedCount = '0',
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder:
        (_) => BlocProvider<CubitCola>.value(
          value: sl<CubitCola>(),
          child: SettingsSheet(
            username: username,
            isDark: isDark,
            onThemeChanged: onThemeChanged,
            onLanguageChanged: onLanguageChanged,
            likedCount: likedCount,
            downloadedCount: downloadedCount,
          ),
        ),
  );
}

// ─────────────────────────────────────────────────────
//  Root widget
// ─────────────────────────────────────────────────────
class SettingsSheet extends StatefulWidget {
  final String username;
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onLanguageChanged;
  final String likedCount;
  final String downloadedCount;

  const SettingsSheet({
    super.key,
    required this.username,
    required this.isDark,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    this.likedCount = '0',
    this.downloadedCount = '0',
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}
