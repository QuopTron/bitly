// ─────────────────────────────────────────────────────────────
// tarjeta_grilla_color_wrapper.dart — PART de tarjeta_grilla.dart: wrapper que extrae el color dominante del cover de forma asincrona (solo modo Spotify).
// Se conecta con: tarjeta_grilla.dart (misma library) + paleta_portada.
// Parte del flujo: Feed/Biblioteca (color dominante de tarjeta de grilla).
// ─────────────────────────────────────────────────────────────

part of 'tarjeta_grilla.dart';

// Wrapper que extrae el color dominante del cover de forma asíncrona.
/// Solo se usa en modo Spotify cuando no se proporciona colorDominante.
class _TarjetaGrillaColorWrapper extends StatefulWidget {
  final String coverUrl;
  final Widget Function(Color? colorDominante) builder;

  const _TarjetaGrillaColorWrapper({
    required this.coverUrl,
    required this.builder,
  });

  @override
  State<_TarjetaGrillaColorWrapper> createState() =>
      _TarjetaGrillaColorWrapperState();
}

class _TarjetaGrillaColorWrapperState extends State<_TarjetaGrillaColorWrapper> {
  Color? _color;

  @override
  void initState() {
    super.initState();
    _extraerColor();
  }

  @override
  void didUpdateWidget(covariant _TarjetaGrillaColorWrapper oldWidget) {
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
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.builder(_color);
}
