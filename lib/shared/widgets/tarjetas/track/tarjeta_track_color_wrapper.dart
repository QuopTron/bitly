// ─────────────────────────────────────────────────────────────
// tarjeta_track_color_wrapper.dart — PART de tarjeta_track.dart:
// wrapper que extrae el color dominante del cover de forma
// asíncrona y reconstruye la tarjeta con él. Solo se usa en modo
// Spotify cuando la tarjeta no recibe un colorDominante ya resuelto.
// Se conecta con: tarjeta_track.dart (misma library) +
// paleta_portada.
// Parte del flujo: búsqueda, feed, mi espacio (filas de tracks).
// ─────────────────────────────────────────────────────────────

part of 'tarjeta_track.dart';

/// Wrapper que extrae el color dominante del cover de forma asíncrona.
/// Solo se usa en modo Spotify cuando no se proporciona colorDominante.
class _TarjetaTrackColorWrapper extends StatefulWidget {
  final String coverUrl;
  final Widget Function(Color? colorDominante) builder;

  const _TarjetaTrackColorWrapper({
    required this.coverUrl,
    required this.builder,
  });

  @override
  State<_TarjetaTrackColorWrapper> createState() =>
      _TarjetaTrackColorWrapperState();
}

class _TarjetaTrackColorWrapperState extends State<_TarjetaTrackColorWrapper> {
  Color? _color;

  @override
  void initState() {
    super.initState();
    _extraerColor();
  }

  @override
  void didUpdateWidget(covariant _TarjetaTrackColorWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl) {
      _extraerColor();
    }
  }

  Future<void> _extraerColor() async {
    try {
      final paleta = await paletaParaPortada(widget.coverUrl);
      if (mounted) {
        setState(() {
          _color = paleta?.dominante;
        });
      }
    } catch (e) {
      debugPrint("[Widget] $e");
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(_color);
}
