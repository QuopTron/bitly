// ─────────────────────────────────────────────────────────────
// settings_estadisticas_detalle.dart — PART de settings_sheet_new
// .dart: sub-modal de detalle de las estadísticas. Se abre al tocar el
// resumen de la pestaña Estadísticas y muestra, con filtros reales, qué
// escuchó el usuario.
//
// Por qué existe: el resumen da cuatro números; acá está el detalle
// exacto (las más repetidas, los minutos que aportó cada una, cuándo fue
// la última vez), que es lo que alimenta la escalera de niveles.
//
// Es una hoja COMPACTA: alto acotado al 62% de la pantalla, cabecera
// chica y carátulas reales en cada fila. El encabezado y los nombres
// localizados están en settings_estadisticas_etiquetas.dart, los filtros
// en ..._detalle_filtros.dart, la lista en ..._detalle_lista.dart y las
// filas en ..._detalle_fila.dart.
//
// Se conecta con: settings_sheet_new.dart (misma library) +
// detalle_escucha + caratulas_escucha + filtro_escucha.
// Parte del flujo: Ajustes → Estadísticas → detalle.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Abre el detalle de escucha como hoja inferior compacta.
Future<void> mostrarDetalleEscucha(
  BuildContext context, {
  required Color glowColor,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _DetalleEscuchaSheet(glowColor: glowColor),
  );
}

/// Hoja de detalle: filtros arriba, lista abajo.
class _DetalleEscuchaSheet extends StatefulWidget {
  final Color glowColor;

  const _DetalleEscuchaSheet({required this.glowColor});

  @override
  State<_DetalleEscuchaSheet> createState() => _DetalleEscuchaSheetState();
}

class _DetalleEscuchaSheetState extends State<_DetalleEscuchaSheet> {
  TipoEscucha _tipo = TipoEscucha.canciones;
  RangoEscucha _rango = RangoEscucha.todo;
  OrdenEscucha _orden = OrdenEscucha.masReproducidas;
  List<FilaEscucha> _filas = const [];
  Map<String, String> _caratulas = const {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    List<FilaEscucha> filas = const [];
    try {
      filas = await sl<DetalleEscucha>().filas(_tipo);
    } catch (e) {
      debugPrint('[Estadísticas] detalle: $e');
    }
    if (!mounted) return;
    setState(() {
      _filas = filas;
      _cargando = false;
    });
    // Las carátulas se resuelven DESPUÉS de pintar la lista: la fila se ve al
    // instante y la portada aparece cuando llega (nunca bloquea el modal).
    try {
      final caratulas = await sl<CaratulasEscucha>().resolver(filas);
      if (mounted) setState(() => _caratulas = caratulas);
    } catch (e) {
      debugPrint('[Estadísticas] carátulas: $e');
    }
  }

  /// Cambia de tipo y recarga solo cuando cambia el tipo: rango y orden se
  /// aplican en memoria, sin volver a leer la base.
  void _cambiarTipo(TipoEscucha tipo) {
    if (tipo == _tipo) return;
    setState(() => _tipo = tipo);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final visibles = aplicarFiltroEscucha(
      _filas,
      rango: _rango,
      orden: _orden,
    );

    return Container(
      // Compacta a propósito: deja ver la pantalla de atrás y se siente como
      // un panel de datos, no como otra pantalla completa.
      constraints: BoxConstraints(maxHeight: r.height * 0.62),
      decoration: BoxDecoration(
        color: ColoresApp.superficie(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TiradorHoja(onBg: onBg, r: r),
          _EncabezadoDetalle(
            minutos: minutosDeFilas(visibles),
            items: visibles.length,
            glowColor: widget.glowColor,
            onBg: onBg,
            r: r,
          ),
          SizedBox(height: r.spacingS * 0.8),
          _BarraFiltrosDetalle(
            tipo: _tipo,
            rango: _rango,
            orden: _orden,
            glowColor: widget.glowColor,
            onBg: onBg,
            r: r,
            onTipo: _cambiarTipo,
            onRango: (rg) => setState(() => _rango = rg),
            onOrden: (o) => setState(() => _orden = o),
          ),
          SizedBox(height: r.spacingS * 0.8),
          Flexible(
            child: _ListaDetalle(
              cargando: _cargando,
              visibles: visibles,
              caratulas: _caratulas,
              glowColor: widget.glowColor,
              onBg: onBg,
              r: r,
            ),
          ),
          SizedBox(height: r.spacingS * 0.8 + insetInferiorSistema(context)),
        ],
      ),
    );
  }
}
