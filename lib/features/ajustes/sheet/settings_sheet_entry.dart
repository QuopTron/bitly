// ─────────────────────────────────────────────────────────────
// settings_sheet_entry.dart — PART de settings_sheet_new.dart:
// punto de entrada de la hoja de Ajustes (showSettingsSheet), la
// lista de pestañas burbuja y el widget SettingsSheet raíz.
// Se conecta con: settings_sheet_new.dart (misma library) +
// cubit_cola + tutorial.
// Parte del flujo: Ajustes (apertura de la hoja).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

// Orden de las pestañas: Apariencia primero (se toca un ajuste, no se mira un
// tablero), después Descargas, Rendimiento, Estadísticas y —las que antes
// vivían apretadas dentro de "Más"— Cuenta, Proveedores y Conexión; Más queda
// última. El orden de íconos y de `StringsAjustes.pestanas` es el mismo.
//
// Acá van SOLO los íconos: las etiquetas salen de `StringsAjustes.pestanas`
// (mismo orden) para que se traduzcan. Es top-level para que los part files
// (p.ej. _BubbleTab y el riel lateral) puedan leerlo.
/// Pestaña de APARIENCIA: es la primera y es donde vive el cofre de diseños,
/// así que su burbuja es la que lleva el mininumerito de regalos.
const int _indiceApariencia = 0;

/// Pestaña de CONEXIÓN: su burbuja lleva el mininumerito de novedades (el
/// regalo de la prueba de 9 h y los aparatos sin vincular).
const int _indiceConexion = 6;

final List<IconData> _iconosPestanas = [
  Icons.palette_outlined,
  Icons.download_rounded,
  Icons.speed_rounded,
  Icons.insights_rounded,
  Icons.workspace_premium_outlined,
  Icons.hub_outlined,
  Icons.devices_rounded,
  Icons.more_horiz,
];

/// Cantidad de pestañas del menú de Ajustes (burbujas en celular, riel en
/// pantalla ancha). TabController y tutorial la usan como largo.
int get cantidadPestanasAjustes => _iconosPestanas.length;

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
  String likedCount = '0',
  String downloadedCount = '0',
  TutorialController? tutorial,
}) {
  // Devuelve el Future de la ruta: quien la abre sabe cuándo se cerró (el
  // tutorial lo necesita para no cerrar algo que el usuario ya cerró).
  return mostrarHoja<void>(
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
    this.likedCount = '0',
    this.downloadedCount = '0',
    this.tutorial,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}
