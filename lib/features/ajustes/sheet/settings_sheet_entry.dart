// ─────────────────────────────────────────────────────────────
// settings_sheet_entry.dart — PART de settings_sheet_new.dart:
// punto de entrada de la hoja de Ajustes (showSettingsSheet), la
// lista de pestañas burbuja y el widget SettingsSheet raíz.
// Se conecta con: settings_sheet_new.dart (misma library) +
// cubit_cola + tutorial.
// Parte del flujo: Ajustes (apertura de la hoja).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

// Tab order: Apariencia first (live color), then Descargas, Rendimiento, Más.
// Top-level para que los part files (p.ej. _BubbleTab) puedan leerlo.
final List<({IconData icon, String label})> _bubbleTabs = [
  (icon: Icons.palette_outlined, label: 'Apariencia'),
  (icon: Icons.download_rounded, label: 'Descargas'),
  (icon: Icons.speed_rounded, label: 'Rendimiento'),
  (icon: Icons.share_outlined, label: 'Compartidos'),
  (icon: Icons.more_horiz, label: 'Más'),
];

/// Reacts to the current queue + playback: when a track is loaded (and has a
/// cover) the sheet gets tinted with the cover's dominant color via a blurred
/// ambient backdrop; when playback stops / queue empties it fades back to the
/// theme's default surface. Colors animate so the transition is smooth.
///
/// [tutorial] es opcional: cuando el tutorial interactivo abre la hoja, se la
/// pasa para que la hoja siga el paso (qué pestaña mostrar).
Future<void> showSettingsSheet(
  BuildContext context, {
  required String username,
  required bool isDark,
  required ValueChanged<bool> onThemeChanged,
  required VoidCallback onLanguageChanged,
  String likedCount = '0',
  String downloadedCount = '0',
  TutorialController? tutorial,
}) {
  // Devuelve el Future de la ruta: quien la abre sabe cuándo se cerró (el
  // tutorial lo necesita para no cerrar algo que el usuario ya cerró).
  return showModalBottomSheet<void>(
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
            tutorial: tutorial,
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

  /// Si el tutorial interactivo abrió la hoja, para seguirlo pestaña por
  /// pestaña. null = uso normal.
  final TutorialController? tutorial;

  const SettingsSheet({
    super.key,
    required this.username,
    required this.isDark,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    this.likedCount = '0',
    this.downloadedCount = '0',
    this.tutorial,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}
