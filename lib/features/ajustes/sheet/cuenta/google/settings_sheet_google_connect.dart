// ─────────────────────────────────────────────────────────────
// settings_sheet_google_connect.dart — PART de settings_sheet_new.dart: lógica de conexión con Google
// (OAuth de YouTube) y manejo del resultado.
// Se conecta con: settings_sheet_new.dart (misma library) + servicio_oauth_youtube.
// Parte del flujo: Ajustes → Más (conectar Google).
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Conecta la cuenta de Google vía OAuth de YouTube y muestra el resultado
/// en un snackbar. Recibe un callback para re-verificar el estado tras
/// conectar (el tile re-renderiza el check).
Future<void> _connectGoogle(
  BuildContext context,
  Future<void> Function() onRecheck,
) async {
  try {
    final resultado = await ServicioOAuthYouTube().conectar(context);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado.mensaje),
          // El color sale del booleano, no del texto: no depende del idioma.
          backgroundColor:
              resultado.ok ? Colors.green.shade700 : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      await onRecheck();
    }
  } catch (e) {
    debugPrint('[settings_sheet_google_connect] $e');
    if (context.mounted) {
      final g = AppLocalizations.of(context).google;
      final en = Localizations.localeOf(context).languageCode == 'en';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(g.errorConexion(e, en: en)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
