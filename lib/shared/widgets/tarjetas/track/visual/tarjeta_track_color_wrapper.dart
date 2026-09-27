// ─────────────────────────────────────────────────────────────
// tarjeta_track_color_wrapper.dart — PART de tarjeta_track.dart:
// wrapper que extrae el color dominante del cover de forma
// asíncrona y reconstruye la tarjeta con él. Solo se usa en modo
// Spotify cuando la tarjeta no recibe un colorDominante ya resuelto.
// Se conecta con: tarjeta_track.dart (misma library) +
// paleta_portada.
// Parte del flujo: búsqueda, feed, mi espacio (filas de tracks).
// ─────────────────────────────────────────────────────────────

part of '../base/tarjeta_track.dart';

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
      // Diferida: la tarjeta pide la paleta en pleno scroll, así que el trabajo
      // se agenda como tarea ociosa para no cortar los frames de la lista.
      final paleta = await paletaParaPortadaDiferida(widget.coverUrl);
      if (mounted) {
        setState(() {
          // `acentoTinte` = el color que de verdad domina en el arte. Con un
          // cover blanco o negro puro no hay tono que sacar: devuelve el
          // dominante neutro (antes se le inventaba un color y salía rojo).
          _color = paleta?.acentoTinte;
        });
      }
    } catch (e) {
      debugPrint("[Widget] $e");
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(_color);
}
