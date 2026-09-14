part of 'settings_sheet_new.dart';

/// Soulseek en Ajustes → Más.
///
/// Qué automatiza: el usuario escribe UNA cosa (el nombre que quiere tener en
/// la red) y al tocar "Siguiente" la app genera la contraseña, conecta, y la
/// cuenta queda creada — porque en Soulseek conectar ES registrarse, lo da de
/// alta el propio servidor en ese paso. Sin mail, sin captcha, sin pago.
///
/// DISEÑO NO INVASIVO
/// En el tab "Más" esto es una línea de texto y un tile, igual que Google: no
/// hay campos a la vista ni párrafos que explicar. El campo aparece recién en
/// la hoja que se abre al tocar el tile, así que no ocupa espacio ni pide nada
/// hasta que el usuario lo pide. Una vez conectado, el tile se pinta con el
/// acento de la app y un check, y no vuelve a aparecer nada más.
///
/// La contraseña es invisible por defecto (no hay nada que memorizar), pero se
/// puede revelar: Soulseek no tiene recuperación de contraseña, así que
/// esconderla del todo sería regalar la cuenta al primer olvido.
class _SoulseekCard extends StatelessWidget {
  final Color glowColor;

  const _SoulseekCard({required this.glowColor});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.hub_rounded, color: glowColor, size: r.subtitleSize),
            SizedBox(width: r.spacingS),
            Text(
              'Soulseek',
              style: TextStyle(
                fontSize: r.subtitleSize,
                fontWeight: FontWeight.w700,
                color: onBg,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          'Música en FLAC compartida entre usuarios. Sin invitación, sin pago '
          'y sin cuentas de otros servicios.',
          style: TextStyle(
            fontSize: r.footerSize - 1,
            color: onBg.withValues(alpha: 0.5),
            height: 1.3,
          ),
        ),
        SizedBox(height: r.spacingS),
        _SoulseekTile(glowColor: glowColor),
      ],
    );
  }
}

/// Círculo con el ícono de Soulseek, para el tile y la hoja. El halo usa el
/// acento de la app en vez de un color propio, así respeta el tema elegido.
class _SoulseekBadge extends StatelessWidget {
  final Color glowColor;
  final double size;

  const _SoulseekBadge({required this.glowColor, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            glowColor.withValues(alpha: 0.30),
            glowColor.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(Icons.hub_rounded, size: size * 0.5, color: glowColor),
      ),
    );
  }
}

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
      // la hoja se cierra y el tile ya quedó pintado, así que no hace falta
      // dejar un cartel pegado en el panel.
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
    final glow = widget.glowColor;

    if (_cargando) {
      return Container(
        padding: EdgeInsets.all(r.spacingM),
        decoration: BoxDecoration(
          color: onBg.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: onBg.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: glow),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _abrir,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(r.spacingM),
        decoration: BoxDecoration(
          gradient:
              _conectada
                  ? LinearGradient(
                    colors: [
                      glow.withValues(alpha: 0.16),
                      glow.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : null,
          color: _conectada ? null : onBg.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                _conectada
                    ? glow.withValues(alpha: 0.35)
                    : onBg.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            _SoulseekBadge(glowColor: glow),
            SizedBox(width: r.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _conectada
                        ? 'Soulseek conectado'
                        : (_usuarioApp.isNotEmpty
                            ? 'Sincronizar Soulseek'
                            : 'Conectar Soulseek'),
                    style: TextStyle(
                      fontSize: r.subtitleSize - 1,
                      fontWeight: FontWeight.w600,
                      color: _conectada ? glow : onBg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _conectada
                        ? '@$_usuario'
                        : (_usuarioApp.isNotEmpty
                            ? 'Usar tu nombre: $_usuarioApp'
                            : 'Elegís un nombre y listo'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r.footerSize - 2,
                      color: onBg.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _conectada
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              color: _conectada ? glow : onBg.withValues(alpha: 0.3),
              size: r.subtitleSize,
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja de alta/conexión. Es lo único que pide un dato, y solo existe mientras
/// está abierta: un nombre, una línea que explica qué pasa, y el botón que
/// crea la cuenta. Si ya hay cuenta, se muestra el estado y la opción de ver
/// la contraseña.
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
      // Sin cuenta de Soulseek todavía: se propone el nombre que el usuario
      // ya eligió en la app (es el caso de quien ya la tenía instalada). El
      // campo queda editable: si ese nombre no le sirve, elige otro acá.
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
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final bg = ColoresApp.superficie(isDark);
    final glow = widget.glowColor;

    return Container(
      margin: EdgeInsets.only(top: r.spacingXL * 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Padding(
          // Deja lugar al teclado: sin esto el campo queda tapado al escribir.
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: r.spacingM),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: onBg.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: r.spacingM),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spacingM),
                child: Row(
                  children: [
                    _SoulseekBadge(glowColor: glow, size: 34),
                    SizedBox(width: r.spacingS),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Soulseek',
                            style: TextStyle(
                              fontSize: r.subtitleSize,
                              fontWeight: FontWeight.w700,
                              color: onBg,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _conectada
                                ? 'Cuenta conectada'
                                : 'Sin mail, sin captcha, sin invitación',
                            style: TextStyle(
                              fontSize: r.footerSize - 2,
                              color: onBg.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.spacingM),
              if (!_datosListos)
                Padding(
                  padding: EdgeInsets.all(r.spacingL),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: glow,
                    ),
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nombreCtrl,
                        enabled: !_cargando,
                        // Abre el teclado solo si no hay un nombre guardado:
                        // si ya lo hay, el gesto útil es el botón.
                        autofocus: _nombreCtrl.text.isEmpty,
                        maxLength: 30,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _cargando ? null : _siguiente(),
                        decoration: InputDecoration(
                          labelText: 'Tu nombre en Soulseek',
                          hintText: 'p. ej. pablo_bz',
                          isDense: true,
                          counterText: '',
                          prefixIcon: Icon(
                            Icons.alternate_email_rounded,
                            size: 18,
                            color: onBg.withValues(alpha: 0.4),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        style: TextStyle(
                          color: onBg,
                          fontSize: r.subtitleSize - 1,
                        ),
                      ),
                      if (_propuestaDeLaApp && !_conectada) ...[
                        SizedBox(height: r.spacingS),
                        Text(
                          'Es el nombre de tu cuenta de la app. Si no te sirve, '
                          'cambiá lo que quieras antes de continuar.',
                          style: TextStyle(
                            fontSize: r.footerSize - 1,
                            color: glow.withValues(alpha: 0.8),
                            height: 1.3,
                          ),
                        ),
                      ],
                      SizedBox(height: r.spacingS),
                      Text(
                        'Al tocar Siguiente se crea tu cuenta con ese nombre. '
                        'La contraseña la genera la app.',
                        style: TextStyle(
                          fontSize: r.footerSize - 1,
                          color: onBg.withValues(alpha: 0.45),
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: r.spacingM),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _cargando ? null : _siguiente,
                          style: FilledButton.styleFrom(
                            backgroundColor: glow,
                            minimumSize: Size.fromHeight(
                              r.continueButtonHeight,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              _cargando
                                  ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : Text(
                                    _conectada ? 'Reconectar' : 'Siguiente',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                        ),
                      ),
                      if (_mensaje != null) ...[
                        SizedBox(height: r.spacingS),
                        Text(
                          _mensaje!,
                          style: TextStyle(
                            fontSize: r.footerSize - 1,
                            color: Colors.red.shade600,
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (_password.isNotEmpty) ...[
                        SizedBox(height: r.spacingS),
                        Divider(color: onBg.withValues(alpha: 0.08)),
                        Row(
                          children: [
                            Icon(
                              Icons.key_rounded,
                              size: r.footerSize + 2,
                              color: onBg.withValues(alpha: 0.45),
                            ),
                            SizedBox(width: r.spacingS),
                            Expanded(
                              child: Text(
                                _revelada
                                    ? 'Guardala: Soulseek no tiene recuperación'
                                    : 'Contraseña guardada',
                                style: TextStyle(
                                  fontSize: r.footerSize - 1,
                                  color: onBg.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  () => setState(() => _revelada = !_revelada),
                              child: Text(
                                _revelada ? 'Ocultar' : 'Ver',
                                style: TextStyle(
                                  fontSize: r.footerSize,
                                  color: glow,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_revelada)
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(r.spacingS),
                            decoration: BoxDecoration(
                              color: onBg.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: onBg.withValues(alpha: 0.08),
                              ),
                            ),
                            child: SelectableText(
                              _password,
                              style: TextStyle(
                                fontSize: r.subtitleSize - 2,
                                color: onBg.withValues(alpha: 0.85),
                                height: 1.3,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              SizedBox(height: r.bottomPadding),
            ],
          ),
        ),
      ),
    );
  }
}
