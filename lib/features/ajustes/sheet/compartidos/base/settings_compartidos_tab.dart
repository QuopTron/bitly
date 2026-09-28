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
// Las dos cosas se GIRAN (mismo carrusel que Apariencia): son dos preguntas
// distintas ("¿cómo vengo escuchando?" y "¿qué me mandaron?") y apiladas
// obligaban a bajar para llegar a la segunda.
//
// Las estadísticas salen del mismo dato local que usa el perfil
// (ReproduccionStats): no hay un segundo contador que pueda divergir.
//
// Se conecta con: settings_sheet_new.dart (misma library) +
// servicio_historial_compartidos + ServicioCompartir + CubitCola +
// ReproduccionStats + niveles_escucha.
// Parte del flujo: Ajustes → Estadísticas.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

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
    final resuelto = await ServicioCompartir.instance.resolver(entrada.datos);
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

    // Mientras se leen las dos fuentes locales se muestra un esqueleto con LA
    // FORMA de la pestaña (el resumen de cuatro números arriba y las filas de
    // abajo) y no una ruedita: la ruedita no dice qué va a aparecer y el
    // contenido después "salta" de la nada.
    if (_cargando) {
      return _EsqueletoEstadisticas(glowColor: widget.glowColor, r: r);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final ms = _stats?.totalTiempoReproducidoMs ?? 0;
    final progreso = ProgresoEscucha.desdeMs(ms);
    final t = AppLocalizations.of(context).ajustes;

    return CarruselAjustes(
      key: const ValueKey('carrusel-estadisticas'),
      etiqueta: t.estadisticas,
      glowColor: widget.glowColor,
      onBg: onBg,
      r: r,
      paginas: [
        // Página 1: cómo viene escuchando (dato local, sin red).
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
          ],
        ),
        // Página 2: quién le compartió qué.
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

/// Esqueleto de la pestaña Estadísticas: la silueta del resumen (cuatro
/// números), del bloque de niveles y de las filas de compartidos.
///
/// No inventa formas nuevas: repite la estructura de `_ResumenEscucha` (cuatro
/// columnas con icono y número), de `_NivelesEscuchaCard` (un bloque alto) y de
/// `_ListaCompartidos` (carátula + dos líneas), con los mismos aire y radio.
class _EsqueletoEstadisticas extends StatelessWidget {
  final Color glowColor;
  final Responsive r;

  const _EsqueletoEstadisticas({required this.glowColor, required this.r});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(r.spacingL, r.spacingS, r.spacingL, r.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El resumen: una tarjeta con cuatro columnas (icono, número, rótulo).
          Container(
            padding: EdgeInsets.all(r.spacingM),
            decoration: BoxDecoration(
              color: glowColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: glowColor.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Column(
                      children: [
                        const EsqueletoCarga(
                          ancho: 22,
                          alto: 22,
                          radioBorde: 11,
                        ),
                        SizedBox(height: r.spacingXS),
                        const EsqueletoCarga(
                          ancho: 40,
                          alto: 14,
                          radioBorde: 6,
                        ),
                        SizedBox(height: r.spacingXS),
                        const EsqueletoCarga(
                          ancho: 56,
                          alto: 10,
                          radioBorde: 5,
                        ),
                      ],
                    ),
                  ),
                // La flecha de "esto se toca".
                EsqueletoCarga(
                  ancho: r.subtitleSize,
                  alto: r.subtitleSize,
                  radioBorde: 6,
                ),
              ],
            ),
          ),
          SizedBox(height: r.spacingM),
          // Los niveles: un bloque alto con su barra de progreso.
          EsqueletoCarga(alto: r.spacingL * 4, radioBorde: 16),
          SizedBox(height: r.spacingM),
          // Y los compartidos: carátula + dos líneas, como cada fila real.
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) SizedBox(height: r.spacingS),
            Row(
              children: [
                EsqueletoCarga(
                  ancho: r.spacingL * 1.6,
                  alto: r.spacingL * 1.6,
                  radioBorde: 10,
                ),
                SizedBox(width: r.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EsqueletoCarga(alto: r.footerSize, radioBorde: 6),
                      SizedBox(height: r.spacingXS),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.5,
                        child: EsqueletoCarga(
                          alto: r.footerSize,
                          radioBorde: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
