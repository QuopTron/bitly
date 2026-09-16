// ─────────────────────────────────────────────────────────────
// settings_compartidos_tab.dart — PART de settings_sheet_new.dart:
// pestaña "Compartidos" — la lista de quién te compartió qué.
//
// Muestra, del más nuevo al más viejo: quién lo mandó, la canción con
// su carátula, el ISRC y cuándo llegó. Tocar una la vuelve a resolver y
// la encola al final, que es lo natural después de verla.
//
// Se conecta con: settings_sheet_new.dart (misma library) +
// servicio_historial_compartidos + ServicioCompartir + CubitCola.
// Parte del flujo: Ajustes → Compartidos.
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

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final items = await ServicioHistorialCompartidos.instance.cargar();
    if (!mounted) return;
    setState(() {
      _items = items;
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
    final l = AppLocalizations.of(context).setup;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(r.spacingL, r.spacingS, r.spacingL, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.compartidosLabel,
                  style: TextStyle(
                    fontSize: r.subtitleSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              if (_items.isNotEmpty)
                TextButton(
                  onPressed: _borrar,
                  child: Text(l.compartidosBorrar),
                ),
            ],
          ),
        ),
        Expanded(
          child: _items.isEmpty
              ? _vacio(r, l.compartidosVacio)
              : ListView.separated(
                  padding: EdgeInsets.all(r.spacingL),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => SizedBox(height: r.spacingS),
                  itemBuilder: (context, i) => _filaCompartido(
                    context,
                    r,
                    _items[i],
                    onTap: () => _encolar(_items[i]),
                  ),
                ),
        ),
      ],
    );
  }
}
