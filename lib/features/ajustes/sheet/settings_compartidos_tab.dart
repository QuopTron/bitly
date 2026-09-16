// ─────────────────────────────────────────────────────────────
// settings_compartidos_tab.dart — PART de settings_sheet_new.dart:
// pestaña "Estadísticas", que ahora reúne las DOS cosas que el usuario
// mira junta: cómo viene escuchando (horas, niveles y premios) y quién
// le compartió qué.
//
// Del más nuevo al más viejo: quién lo mandó, la canción con su
// carátula, el ISRC y cuándo llegó. Tocar una la vuelve a resolver y la
// encola al final, que es lo natural después de verla.
//
// Las estadísticas salen del mismo dato local que usa el perfil
// (ReproduccionStats): no hay un segundo contador que pueda divergir.
//
// Se conecta con: settings_sheet_new.dart (misma library) +
// servicio_historial_compartidos + ServicioCompartir + CubitCola +
// ReproduccionStats + niveles_escucha.
// Parte del flujo: Ajustes → Estadísticas.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Lista de compartidos recibidos, con opción de borrar el historial.
class _CompartidosTab extends StatefulWidget {
  final Color glowColor;

  const _CompartidosTab({required this.glowColor});

  @override
  State<_CompartidosTab> createState() => _CompartidosTabState();
}

class _CompartidosTabState extends State<_CompartidosTab> {
  List<CompartidoRecibido> _items = const [];
  bool _cargando = true;

  /// Stats de escucha (mismo dato que el perfil) para la cabecera.
  EstadisticasUsuario? _stats;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    // Las dos fuentes son locales y baratas; si una falla, la otra se muestra
    // igual (nunca dejamos la pestaña en blanco).
    List<CompartidoRecibido> items = const [];
    EstadisticasUsuario? stats;
    try {
      items = await ServicioHistorialCompartidos.instance.cargar();
    } catch (e) {
      debugPrint('[Estadísticas] historial de compartidos: $e');
    }
    try {
      stats = await sl<ReproduccionStats>().getStatsUsuario();
    } catch (e) {
      debugPrint('[Estadísticas] stats locales: $e');
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _stats = stats;
      _cargando = false;
    });
  }

  Future<void> _borrar() async {
    await ServicioHistorialCompartidos.instance.limpiar();
    if (!mounted) return;
    setState(() => _items = const []);
  }

  /// Vuelve a resolver la canción y la encola sin cortar lo que suena.
  Future<void> _encolar(CompartidoRecibido entrada) async {
    final resuelto =
        await ServicioCompartir.instance.resolver(entrada.datos);
    if (!mounted || resuelto == null) return;
    sl<CubitCola>().agregarAlFinal(resuelto.item);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(resuelto.item.name),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    if (_cargando) {
      return Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: widget.glowColor,
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final ms = _stats?.totalTiempoReproducidoMs ?? 0;
    final progreso = ProgresoEscucha.desdeMs(ms);

    // Una sola lista: cabecera de escucha + niveles + compartidos. Así todo
    // scrollea junto y la pestaña no queda partida en dos zonas.
    return ListView(
      padding: EdgeInsets.all(r.spacingL),
      children: [
        _ResumenEscucha(
          stats: _stats,
          milisegundos: ms,
          glowColor: widget.glowColor,
          onBg: onBg,
          r: r,
        ),
        if (_stats != null) ...[
          SizedBox(height: r.spacingM),
          _NivelesEscuchaCard(
            progreso: progreso,
            horasTotales: ms ~/ 3600000,
            glowColor: widget.glowColor,
            onBg: onBg,
            r: r,
          ),
        ],
        SizedBox(height: r.spacingM),
        _ListaCompartidos(
          items: _items,
          glowColor: widget.glowColor,
          onBg: onBg,
          r: r,
          onBorrar: _borrar,
          onTocar: _encolar,
        ),
      ],
    );
  }
}
