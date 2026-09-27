// ─────────────────────────────────────────────────────────────
// tarjeta_grilla_color_wrapper.dart — PART de tarjeta_grilla.dart: wrapper que extrae el color dominante del cover de forma asincrona (solo modo Spotify).
// Se conecta con: tarjeta_grilla.dart (misma library) + paleta_portada.
// Parte del flujo: Feed/Biblioteca (color dominante de tarjeta de grilla).
// ─────────────────────────────────────────────────────────────

part of '../base/tarjeta_grilla.dart';

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

class _TarjetaGrillaColorWrapperState
    extends State<_TarjetaGrillaColorWrapper> {
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
      // DIFERIDA, igual que la tarjeta de fila: la grilla vive en el feed y en
      // la biblioteca, así que también pide la paleta en pleno scroll. Con la
      // versión directa, cada portada nueva hacia su decode + `toByteData`
      // (lectura GPU→CPU) EN EL FRAME en curso: era el mismo trabajo que la
      // tarjeta de fila ya había movido a tarea ociosa, pero acá seguía
      // cortando el scroll.
      final paleta = await paletaParaPortadaDiferida(widget.coverUrl);
      if (mounted) {
        setState(() {
          // `acentoTinte` = el color que de verdad domina en el arte.
          _color = paleta?.acentoTinte;
        });
      }
    } catch (e) {
      // Sin paleta la tarjeta usa su color por defecto: no es un fallo visible
      // para el usuario, pero conviene saber que la portada no dio color.
      debugPrint('[Grilla] no se pudo sacar el color de la portada: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(_color);
}
