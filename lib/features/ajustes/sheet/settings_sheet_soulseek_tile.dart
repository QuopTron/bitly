// ─────────────────────────────────────────────────────────────
// settings_sheet_soulseek_tile.dart — PART de settings_sheet_new
// .dart: tile de estado de Soulseek. Sin conexión invita a
// conectar; con conexión se pinta con el acento y muestra el
// nombre. En ambos casos, tocar abre la hoja de alta/conexión.
// Se conecta con: settings_sheet_new.dart (misma library) +
// servicio_soulseek + settings_sheet_soulseek_sheet.
// Parte del flujo: Ajustes → Más (Soulseek).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Tile de estado. Sin conexión: invita a conectar. Con conexión: se pinta con
/// el acento y muestra el nombre. En los dos casos, tocar abre la hoja.
class _SoulseekTile extends StatefulWidget {
  final Color glowColor;

  const _SoulseekTile({required this.glowColor});

  @override
  State<_SoulseekTile> createState() => _SoulseekTileState();
}

class _SoulseekTileState extends State<_SoulseekTile> {
  final _servicio = ServicioSoulseek();

  bool _cargando = true;
  bool _conectada = false;
  String _usuario = '';
  String _usuarioApp = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final usuario = await _servicio.usuarioGuardado;
      final password = await _servicio.passwordGuardada;
      // El nombre de la app es el que se propone para la cuenta: a los que ya
      // tenían la app no hay que pedirles que lo escriban de nuevo.
      final app = await _servicio.usuarioDeLaApp;
      if (!mounted) return;
      setState(() {
        _usuario = usuario;
        _usuarioApp = app;
        _conectada = usuario.isNotEmpty && password.isNotEmpty;
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _abrir() async {
    final conecto = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SoulseekSheet(glowColor: widget.glowColor),
    );
    if (!mounted) return;
    await _cargar();
    if (conecto == true && mounted) {
      // El acuse va en un snackbar flotante (igual que la conexión de Google):
      // la hoja se cierra y el tile ya quedó pintado.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Soulseek conectado. Tu cuenta ya está lista.'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    return _SoulseekTileVisual(
      cargando: _cargando,
      conectada: _conectada,
      usuario: _usuario,
      usuarioApp: _usuarioApp,
      glow: widget.glowColor,
      onBg: onBg,
      r: r,
      onTap: _abrir,
    );
  }
}
