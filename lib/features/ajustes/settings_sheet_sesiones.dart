// ─────────────────────────────────────────────────────────────
// settings_sheet_sesiones.dart — PART de settings_sheet_new.dart:
// tarjeta "Sesiones de fuentes" del tab Más y su hoja de detalle.
//
// Muestra el estado de la sesión firmada (Cloudflare) de CADA fuente
// que la soporta y permite renovarla o verificarla de a una. Ese es el
// flujo para migrar/renovar las fuentes una por una sin abrir los
// challenges de todas juntas.
//
// Las sesiones del gateway son de vida corta (~1-2 min), así que el
// estado mostrado es un snapshot del instante: el keepalive las refresca
// solo mientras la app vive (ver verificacion_keepalive.dart).
// Se conecta con: contrato_backend (getSignedSessionStatus,
// keepAliveSignedSessions) + servicio_verificacion (verificarFuente) +
// l10n + responsive + contenedor_vidrio.
// Parte del flujo: Ajustes → Más → Sesiones de fuentes.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Fuentes que soportan sesión firmada. Espeja los manifests de
/// assets/extensions/* con `signedSession` configurado.
const _fuentesSesionFirmada = <String>[
  'qobuz-web',
  'tidal-web',
  'deezer',
  'amazon',
];

/// Tarjeta del tab "Más": estado de las sesiones firmadas por fuente.
class _SesionesCard extends StatelessWidget {
  final Color glowColor;

  const _SesionesCard({required this.glowColor});

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
            Icon(Icons.verified_user_outlined, color: glowColor, size: r.subtitleSize),
            SizedBox(width: r.spacingS),
            Text(
              'Sesiones de fuentes',
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
          'Revisa y renueva la verificación de cada fuente. Al cerrar la app '
          'las sesiones se apagan, así que conviene renovarlas antes de usarlas.',
          style: TextStyle(
            fontSize: r.footerSize - 1,
            color: onBg.withValues(alpha: 0.5),
            height: 1.3,
          ),
        ),
        SizedBox(height: r.spacingS),
        GestureDetector(
          onTap: () => showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => _SesionesSheet(glowColor: glowColor),
          ),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: r.spacingS),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: onBg.withValues(alpha: 0.1)),
              color: onBg.withValues(alpha: 0.03),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: r.footerSize + 1, color: onBg.withValues(alpha: 0.7)),
                SizedBox(width: r.spacingXS),
                Text(
                  'Ver sesiones',
                  style: TextStyle(
                    fontSize: r.footerSize,
                    fontWeight: FontWeight.w600,
                    color: onBg.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Hoja con el estado y las acciones por fuente.
class _SesionesSheet extends StatefulWidget {
  final Color glowColor;

  const _SesionesSheet({required this.glowColor});

  @override
  State<_SesionesSheet> createState() => _SesionesSheetState();
}

class _SesionesSheetState extends State<_SesionesSheet> {
  final Map<String, EstadoSesionFirmada> _estados = {};
  final Set<String> _ocupadas = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarEstados();
  }

  /// Consulta el estado de cada fuente (silencioso: nunca abre challenges).
  Future<void> _cargarEstados() async {
    final backend = sl<BackendService>();
    for (final fuente in _fuentesSesionFirmada) {
      try {
        final estado = await backend.getSignedSessionStatus(fuente);
        _estados[fuente] = estado;
      } catch (_) {
        _estados[fuente] = const EstadoSesionFirmada();
      }
    }
    if (mounted) setState(() => _cargando = false);
  }

  /// Pide al backend un pase de keepalive y refresca la vista.
  Future<void> _renovar(String fuente) async {
    setState(() => _ocupadas.add(fuente));
    try {
      await sl<BackendService>().keepAliveSignedSessions();
      final estado = await sl<BackendService>().getSignedSessionStatus(fuente);
      _estados[fuente] = estado;
    } catch (_) {
      // Silencioso: el estado se vuelve a leer igual.
    } finally {
      if (mounted) setState(() => _ocupadas.remove(fuente));
    }
  }

  /// Corre el challenge humano solo para esta fuente.
  Future<void> _verificar(String fuente) async {
    setState(() => _ocupadas.add(fuente));
    try {
      final ok = await ServicioVerificacion().verificarFuente(fuente);
      if (ok) {
        final estado = await sl<BackendService>().getSignedSessionStatus(fuente);
        _estados[fuente] = estado;
      }
    } catch (_) {
      // El servicio ya loguea el detalle; la UI solo refresca el estado.
    } finally {
      if (mounted) setState(() => _ocupadas.remove(fuente));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);

    return Padding(
      padding: EdgeInsets.all(r.spacingL),
      child: ContenedorVidrio(
        borderRadius: 22,
        borderColor: onBg.withValues(alpha: 0.08),
        bgColor: ColoresApp.superficie(isDark).withValues(alpha: 0.96),
        padding: EdgeInsets.all(r.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sesiones de fuentes',
              style: TextStyle(
                fontSize: r.subtitleSize + 4,
                fontWeight: FontWeight.w800,
                color: onBg,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Las sesiones duran ~1-2 minutos; la app las renueva sola mientras '
              'está abierta. Toca Verificar solo si una fuente dejó de responder.',
              style: TextStyle(
                fontSize: r.footerSize - 1,
                color: onBg.withValues(alpha: 0.45),
                height: 1.3,
              ),
            ),
            SizedBox(height: r.spacingM),
            if (_cargando)
              Padding(
                padding: EdgeInsets.symmetric(vertical: r.spacingL),
                child: Center(
                  child: SizedBox(
                    width: r.subtitleSize,
                    height: r.subtitleSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: onBg.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              )
            else
              for (final fuente in _fuentesSesionFirmada)
                _filaFuente(fuente, onBg, r),
            SizedBox(height: r.spacingS),
            _botonRenovarTodas(onBg, r),
          ],
        ),
      ),
    );
  }

  /// Fila de una fuente: nombre, estado y acciones.
  Widget _filaFuente(String fuente, Color onBg, Responsive r) {
    final estado = _estados[fuente] ?? const EstadoSesionFirmada();
    final ocupada = _ocupadas.contains(fuente);
    final nombre = ServicioVerificacion().nombreFuente(fuente);
    final expira = estado.expiraEn != null
        ? DateTime.tryParse(estado.expiraEn!)
        : null;
    final restante = expira != null ? expira.difference(DateTime.now()) : null;
    final viva = estado.autenticado &&
        (restante == null || restante.inSeconds > 0);

    final descripcion = estado.error ??
        (viva
            ? (restante != null
                ? 'Activa · expira en ${restante.inSeconds}s'
                : 'Activa')
            : 'Sin sesión activa');

    return Padding(
      padding: EdgeInsets.only(bottom: r.spacingS),
      child: Row(
        children: [
          Icon(
            viva ? Icons.check_circle_outline : Icons.error_outline,
            size: r.footerSize + 3,
            color: onBg.withValues(alpha: viva ? 0.75 : 0.4),
          ),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: TextStyle(
                    fontSize: r.footerSize,
                    fontWeight: FontWeight.w700,
                    color: onBg,
                  ),
                ),
                Text(
                  descripcion,
                  style: TextStyle(
                    fontSize: r.footerSize - 2,
                    color: onBg.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          _accion('Renovar', ocupada, onBg, r, () => _renovar(fuente)),
          SizedBox(width: r.spacingXS),
          _accion('Verificar', ocupada, onBg, r, () => _verificar(fuente)),
        ],
      ),
    );
  }

  /// Botón compacto de acción por fuente.
  Widget _accion(
    String texto,
    bool ocupada,
    Color onBg,
    Responsive r,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: ocupada ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: onBg.withValues(alpha: 0.12)),
          color: onBg.withValues(alpha: 0.04),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: r.footerSize - 2,
            fontWeight: FontWeight.w600,
            color: onBg.withValues(alpha: ocupada ? 0.3 : 0.8),
          ),
        ),
      ),
    );
  }

  /// Renueva todas las fuentes de una sola vez.
  Widget _botonRenovarTodas(Color onBg, Responsive r) {
    return SizedBox(
      width: double.infinity,
      height: r.continueButtonHeight,
      child: GestureDetector(
        onTap: () async {
          for (final fuente in _fuentesSesionFirmada) {
            await _renovar(fuente);
          }
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: onBg.withValues(alpha: 0.12)),
            color: onBg.withValues(alpha: 0.04),
          ),
          child: Text(
            'Renovar todas',
            style: TextStyle(
              fontSize: r.subtitleSize,
              fontWeight: FontWeight.w600,
              color: onBg.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}
