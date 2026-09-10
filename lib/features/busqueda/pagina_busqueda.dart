// ─────────────────────────────────────────────────────────────
// pagina_busqueda.dart — Página de búsqueda: State con la fuente
// persistida, la categoría activa y el debounce, más el selector
// de variante móvil/escritorio. El flujo (persistencia + handlers)
// vive en pagina_busqueda_flujo.dart, los helpers de fuente/filtros
// y acciones en pagina_busqueda_helpers.dart y las piezas del
// layout en pagina_busqueda_widgets.dart — cero duplicación.
// Se conecta con: busqueda_bloc + cache_ajustes + deteccion_
// plataforma + busqueda_movil/busqueda_escritorio.
// Parte del flujo: búsqueda (vista completa).
// ─────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/inyeccion.dart';
import '../../core/cache/cache_ajustes.dart';
import '../../core/modelos/config_busqueda_fuente.dart';
import '../../core/modelos/item_feed.dart';
import '../../shared/constantes/constantes_fuente.dart';
import '../../shared/tema/colores_app.dart';
import '../../shared/utilidades/acciones_item.dart';
import '../../shared/utilidades/deteccion_plataforma.dart';
import '../../shared/widgets/acordeon_fuente.dart';
import 'bloc/busqueda_bloc.dart';
import 'bloc/busqueda_estado.dart';
import 'bloc/busqueda_evento.dart';
import 'busqueda_escritorio.dart';
import 'busqueda_movil.dart';
import 'widgets/barra_busqueda.dart';
import 'widgets/busqueda_cuerpo.dart';
import 'widgets/chips_tipo_busqueda.dart';

part 'pagina_busqueda_flujo.dart';
part 'pagina_busqueda_helpers.dart';
part 'pagina_busqueda_widgets.dart';

/// Página de búsqueda con variante móvil/escritorio.
class PaginaBusqueda extends StatefulWidget {
  /// Navegación opcional al detalle de un ítem (lo cablea el shell;
  /// null = el tap en tarjetas de grilla queda inerte hasta migrar detail).
  final void Function(ItemFeed item)? onNavegarItem;

  const PaginaBusqueda({super.key, this.onNavegarItem});

  @override
  State<PaginaBusqueda> createState() => _PaginaBusquedaState();
}

class _PaginaBusquedaState extends State<PaginaBusqueda> {
  final TextEditingController _controlador = TextEditingController();
  Timer? _debounce;

  /// Fuente de búsqueda activa — cada búsqueda apunta a una extensión.
  String _fuente = '';

  /// Categoría activa: siempre hay una ('tracks' por defecto), sin modo "all".
  String? _tipo = 'tracks';

  bool _buscando = false;
  static const _prefKey = 'search_source';

  /// Wrapper público para que los parts puedan llamar setState.
  void _aplicar(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _cargarFuentePersistida(this);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BlocBusqueda, EstadoBusqueda>(
      listenWhen: (prev, cur) => prev.cargando && !cur.cargando,
      listener: (_, _) {
        if (mounted) setState(() => _buscando = false);
      },
      child: BlocBuilder<BlocBusqueda, EstadoBusqueda>(
        builder: (context, state) {
          final mostrarResultados = _controlador.text.trim().isNotEmpty;
          final mostrarRecientes =
              !mostrarResultados && state.busquedasRecientes.isNotEmpty;

          final barra = _construirBarra(this, state);
          final chips = _construirChips(this, state);
          final cuerpo = _construirCuerpo(
              this, state, mostrarResultados, mostrarRecientes);

          if (usarLayoutEscritorio(context)) {
            return BusquedaEscritorio(
                barra: barra, chips: chips, cuerpo: cuerpo);
          }
          return BusquedaMovil(barra: barra, chips: chips, cuerpo: cuerpo);
        },
      ),
    );
  }
}