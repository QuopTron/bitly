// ─────────────────────────────────────────────────────────────
// settings_sheet_soulseek_sheet.dart — PART de settings_sheet_new
// .dart: estado y lógica de la hoja de alta/conexión de Soulseek
// (cargar datos guardados y crear/conectar la cuenta). El armazón
// visual vive en settings_sheet_soulseek_sheet_visual.dart.
// Se conecta con: settings_sheet_new.dart (misma library) +
// servicio_soulseek + settings_sheet_soulseek_sheet_visual.
// Parte del flujo: Ajustes → Más (conectar Soulseek).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Hoja de alta/conexión. Si ya hay cuenta, se muestra el estado y la
/// opción de ver la contraseña.
class _SoulseekSheet extends StatefulWidget {
  final Color glowColor;

  const _SoulseekSheet({required this.glowColor});

  @override
  State<_SoulseekSheet> createState() => _SoulseekSheetState();
}

class _SoulseekSheetState extends State<_SoulseekSheet> {
  final _servicio = ServicioSoulseek();
  final _nombreCtrl = TextEditingController();

  bool _datosListos = false;
  bool _cargando = false;
  bool _revelada = false;
  bool _conectada = false;
  bool _propuestaDeLaApp = false;
  String _password = '';
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final usuario = await _servicio.usuarioGuardado;
      final password = await _servicio.passwordGuardada;
      // Sin cuenta todavía: se propone el nombre que el usuario ya eligió en
      // la app (caso de quien ya la tenía instalada). El campo queda editable.
      final app = await _servicio.usuarioDeLaApp;
      final propuesta = usuario.isEmpty ? app : usuario;
      if (!mounted) return;
      setState(() {
        _nombreCtrl.text = propuesta;
        _password = password;
        _propuestaDeLaApp = usuario.isEmpty && app.isNotEmpty;
        _conectada = usuario.isNotEmpty && password.isNotEmpty;
        _datosListos = true;
      });
    } catch (_) {
      if (mounted) setState(() => _datosListos = true);
    }
  }

  /// "Siguiente": genera la contraseña si hace falta, conecta y crea la cuenta.
  /// Un solo gesto, sin pasos intermedios a la vista.
  Future<void> _siguiente() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _mensaje = 'Elegí un nombre para tu cuenta.');
      return;
    }
    setState(() {
      _cargando = true;
      _mensaje = null;
    });
    final resultado = await _servicio.crearOConectar(nombre);
    if (!mounted) return;
    if (resultado.ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _cargando = false;
      _mensaje = resultado.mensaje;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _SoulseekSheetVisual(
      datosListos: _datosListos,
      cargando: _cargando,
      conectada: _conectada,
      propuestaDeLaApp: _propuestaDeLaApp,
      revelada: _revelada,
      password: _password,
      mensaje: _mensaje,
      nombreCtrl: _nombreCtrl,
      glow: widget.glowColor,
      onBg: ColoresApp.enSuperficie(isDark),
      bg: ColoresApp.superficie(isDark),
      r: Responsive(context),
      onSiguiente: _siguiente,
      onToggleRevelada: () => setState(() => _revelada = !_revelada),
    );
  }
}
