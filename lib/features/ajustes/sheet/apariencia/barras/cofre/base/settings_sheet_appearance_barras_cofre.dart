// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_barras_cofre.dart — PART de
// settings_sheet_new.dart: el COFRE DE PALETAS del espacio Barras.
//
// Es un BOTÓN: al tocarlo se despliega el submodal con las paletas (ver
// _CofrePaletasPanel, en _cofre_panel). Se despliega ACÁ MISMO, dentro del
// sheet de Ajustes, y no como un modal encima del otro.
//
// Las horas y la versión se leen una sola vez y best-effort: si fallan, el
// cofre igual se abre (con todo lo no-regalado bloqueado) en vez de romper
// Ajustes. Cuántos regalos quedan lo decide el mismo cálculo que el
// mininumerito de Ajustes: nunca muestran números distintos.
//
// Se conecta con: settings_sheet_appearance_barras.dart (misma library) +
// catalogo_disenos_barra_lista + apariencia_helper.
// Parte del flujo: Ajustes → Apariencia → Barras → Cofre.
// ─────────────────────────────────────────────────────────────

part of '../../../../settings_sheet_new.dart';

/// Cofre: el botón que abre el submodal de paletas.
class _CofreDisenos extends StatefulWidget {
  /// Barra que se está editando (la paleta se aplica a esa).
  final bool navbar;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final StringsCofrePaletas t;

  /// Aparato en el que se está usando la app: el cofre solo muestra sus
  /// diseños y con eso cuenta los regalos.
  final TipoDispositivo aparato;

  /// Nombre ya localizado de ese aparato ("Celular", "TV", "PC").
  final String nombreAparato;

  const _CofreDisenos({
    required this.navbar,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.t,
    required this.aparato,
    required this.nombreAparato,
  });

  @override
  State<_CofreDisenos> createState() => _CofreDisenosState();
}

class _CofreDisenosState extends State<_CofreDisenos> {
  /// Horas escuchadas y versión de la app; null mientras carga.
  (int horas, int version)? _datos;

  /// ¿Está abierto el submodal?
  bool _abierto = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Lee las horas de escucha y la versión de la app: el MISMO dato que usan
  /// los niveles de escucha, así un regalo nunca aparece de más.
  Future<void> _cargar() async {
    try {
      final stats = await sl<ReproduccionStats>().getStatsUsuario();
      final pkg = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _datos = (
          stats.totalTiempoReproducidoMs ~/ 3600000,
          versionEnNumero(pkg.version),
        );
      });
    } catch (e) {
      debugPrint('[Apariencia] cofre sin datos de progreso: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final horas = _datos?.$1 ?? 0;
    final version = _datos?.$2 ?? 0;
    final pendientes = regalosDisponibles(
      horas: horas,
      version: version,
      vistos: AparienciaHelper.actual(context).regalosVistos.toSet(),
      aparato: widget.aparato,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BotonCofre(
          t: widget.t,
          glowColor: widget.glowColor,
          onBg: widget.onBg,
          r: widget.r,
          pendientes: pendientes.length,
          abierto: _abierto,
          onTap: _alternar,
        ),
        // El submodal: se despliega con animación acá mismo.
        AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child:
              _abierto
                  ? _CofrePaletasPanel(
                    navbar: widget.navbar,
                    horas: horas,
                    version: version,
                    aparato: widget.aparato,
                    nombreAparato: widget.nombreAparato,
                    glowColor: widget.glowColor,
                    onBg: widget.onBg,
                    r: widget.r,
                    t: widget.t,
                    onCerrar: () => setState(() => _abierto = false),
                  )
                  : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  /// Abrir o cerrar el submodal. Abrir un regalo es el toque de su paleta,
  /// no este: acá solo se despliega.
  void _alternar() {
    Haptico.seleccion();
    setState(() => _abierto = !_abierto);
  }
}
