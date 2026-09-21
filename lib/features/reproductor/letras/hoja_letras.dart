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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/inyeccion.dart';
import '../../../core/cache/estado/estado_cola.dart';
import '../../../core/cache/estado/estado_reproductor.dart';
import '../../../core/modelos/feed/item_feed.dart';
import '../../../core/servicios/traduccion/servicio_traduccion_letras.dart';
import '../../../estado/cola/cubit_cola.dart';
import '../../../estado/like/cubit_like.dart';
import '../../../estado/reproductor/cubit_reproductor.dart';
import '../../../shared/utilidades/portada/paleta_portada.dart';
import '../../../shared/utilidades/modales/mostrar_modal.dart';
import '../../../shared/utilidades/plataforma/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/texto/mini_karaoke_letra.dart';
import '../../../shared/widgets/texto/texto_linea_letra.dart';
import '../../../shared/widgets/vidrio/fondo_reactivo_portada.dart';

part 'hoja_letras_parse.dart';
part 'hoja_letras_cabecera.dart';
part 'hoja_letras_linea.dart';
part 'hoja_letras_transporte.dart';
part 'hoja_letras_transporte_progreso.dart';
part 'hoja_letras_traduccion.dart';
part 'hoja_letras_fondo.dart';
part 'hoja_letras_util.dart';
part 'hoja_letras_build.dart';

/// Abre la hoja karaoke de letras para [track] con [letras] (LRC o texto).
void mostrarHojaLetras(
  BuildContext context, {
  required ItemFeed track,
  required String letras,
}) {
  mostrarHoja<void>(
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

  /// Ancla de la línea ACTIVA. El centrado del scroll usa su posición real
  /// (ver _sincronizarScroll): las líneas largas ocupan dos renglones, así que
  /// un alto fijo por índice desalineaba el centrado.
  final GlobalKey _claveActiva = GlobalKey();
  final List<_KLine> _lineas = [];
  String _textoPlano = '';
  int _indiceActivo = 0;
  double _altoViewport = 600;
  Future<PaletaPortada?>? _paletaFuture;

  /// Traducción activa, indexada igual que [_lineas] (null = sin traducir, y
  /// una entrada null dentro = esa línea quedó vacía).
  List<String?>? _traducciones;
  String? _idiomaDestino;
  String? _idiomaOrigen;
  bool _traduciendo = false;

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
    } catch (e) {
      debugPrint("[Feature] $e");
    }
    return widget.track.coverUrl;
  }

  /// Identidad estable de la canción para guardar su traducción: el ISRC es lo
  /// único que no cambia entre proveedores; si no lo hay, el id del ítem.
  String _claveCancion(ItemFeed track) {
    final isrc = track.isrc?.trim() ?? '';
    return isrc.isNotEmpty ? 'isrc:$isrc' : 'id:${track.id}';
  }

  /// Traduce la letra al idioma [codigo] (o la oculta si [codigo] es null).
  /// La traducción es ADITIVA: nunca toca las líneas originales ni el karaoke.
  Future<void> traducirA(String? codigo) async {
    if (codigo == null) {
      setState(() {
        _traducciones = null;
        _idiomaDestino = null;
      });
      return;
    }
    if (_traduciendo) return;
    setState(() => _traduciendo = true);
    final res = await sl<ServicioTraduccionLetras>().traducir(
      lineas: [for (final l in _lineas) l.texto],
      destino: codigo,
      // La clave de canción es lo que hace que la traducción se guarde en la
      // base y no se vuelva a pedir al reabrir la misma canción.
      claveCancion: _claveCancion(widget.track),
    );
    if (!mounted) return;
    setState(() {
      _traduciendo = false;
      if (res != null) {
        _traducciones = res.lineas;
        _idiomaOrigen = res.idiomaOrigen;
        _idiomaDestino = codigo;
      }
    });
    // Aviso solo cuando no se pudo: si salió bien, la traducción se ve sola.
    if (res == null && mounted) {
      final loc = AppLocalizations.of(context).letras;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(loc.errorTraduccion),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CubitReproductor>.value(value: sl<CubitReproductor>()),
        BlocProvider<CubitCola>.value(value: sl<CubitCola>()),
      ],
      child: BlocBuilder<CubitReproductor, EstadoAudioReproductor>(
        builder:
            (context, reproductor) =>
                _construirHoja(this, context, reproductor),
      ),
    );
  }
}
