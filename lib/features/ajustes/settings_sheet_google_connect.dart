part of 'settings_sheet_new.dart';

/// Conecta la cuenta de Google vía OAuth de YouTube y muestra el resultado
/// en un snackbar. Recibe un callback para re-verificar el estado tras
/// conectar (el tile re-renderiza el check).
Future<void> _connectGoogle(
  BuildContext context,
  Future<void> Function() onRecheck,
) async {
  try {
    final msg = await ServicioOAuthYouTube().conectar(context);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor:
              msg.startsWith('Sesion de YouTube conectada')
                  ? Colors.green.shade700
                  : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      await onRecheck();
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al conectar: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
