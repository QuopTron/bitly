// ─────────────────────────────────────────────────────────────
// hoja_letras.dart — Modal karaoke de letras (Spotify-style):
// LRC sincronizadas con línea activa centrada, auto-scroll,
// relleno karaoke por palabra (enhanced LRC) o barrido uniforme,
// colores derivados de la paleta de la carátula y controles
// rápidos (seek + prev/play/next/repeat/shuffle) abajo.
// Parts: _parse, _linea, _transporte, _fondo, _util, _build.
// Se conecta con: paleta_portada + cubits + imagen_portada.
// Parte del flujo: reproductor (letras karaoke).
// ─────────────────────────────────────────────────────────────

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/inyeccion.dart';
import '../../core/cache/estado_cola.dart';
import '../../core/cache/estado_reproductor.dart';
import '../../core/modelos/item_feed.dart';
import '../../core/modelos/perfil_rendimiento.dart';
import '../../estado/cubit_cola.dart';
import '../../estado/cubit_like.dart';
import '../../estado/cubit_reproductor.dart';
import '../../shared/utilidades/paleta_portada.dart';
import '../../shared/utilidades/responsive.dart';
import '../../shared/widgets/imagen_portada.dart';

part 'hoja_letras_parse.dart';
part 'hoja_letras_linea.dart';
part 'hoja_letras_transporte.dart';
part 'hoja_letras_fondo.dart';
part 'hoja_letras_util.dart';
part 'hoja_letras_build.dart';

/// Abre la hoja karaoke de letras para [track] con [letras] (LRC o texto).
void mostrarHojaLetras(
  BuildContext context, {
  required ItemFeed track,
  required String letras,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: false,
    builder: (_) => _HojaLetras(track: track, letrasCrudas: letras),
  );
}

/// Una línea sincronizada de letra karaoke.
class _KLine {
  final Duration tiempo;
  final String texto;

  /// Timestamps por palabra (enhanced LRC `<mm:ss.xx>word`). Vacío cuando la
  /// fuente no trae tags — el relleno cae a un barrido uniforme.
  final List<(Duration, String)> palabras;

  const _KLine(this.tiempo, this.texto, [this.palabras = const []]);
}

class _HojaLetras extends StatefulWidget {
  final ItemFeed track;
  final String letrasCrudas;

  const _HojaLetras({required this.track, required this.letrasCrudas});

  @override
  State<_HojaLetras> createState() => _HojaLetrasState();
}

class _HojaLetrasState extends State<_HojaLetras> {
  final ScrollController _scroll = ScrollController();
  final List<_KLine> _lineas = [];
  String _textoPlano = '';
  int _indiceActivo = 0;
  double _altoViewport = 600;
  Future<PaletaPortada?>? _paletaFuture;

  @override
  void initState() {
    super.initState();
    _parsear(this);
    _paletaFuture = paletaParaPortada(_resolverCaratula());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String? _resolverCaratula() {
    try {
      final actual = sl<CubitCola>().state.actual;
      if (actual != null) {
        final resuelta = sl<CubitLikes>().caratulaLocalPara(actual);
        if (resuelta != null) return resuelta;
      }
    } catch (_) {}
    return widget.track.coverUrl;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CubitReproductor>.value(value: sl<CubitReproductor>()),
        BlocProvider<CubitCola>.value(value: sl<CubitCola>()),
      ],
      child: BlocBuilder<CubitReproductor, EstadoAudioReproductor>(
        builder: (context, reproductor) =>
            _construirHoja(this, context, reproductor),
      ),
    );
  }
}