// ─────────────────────────────────────────────────────────────
// modal_cola_fondo.dart — PART de modal_cola.dart: fondo del modal
// de cola — carátula desenfocada con el sigma según el perfil de
// rendimiento (el video en vivo lo maneja ReproductorVideoFondo).
// En modo Spotify, reemplaza el blur por color dominante sólido.
// Se conecta con: modal_cola.dart (misma library) + imagen_portada
// + perfil_rendimiento + estilo_helper + paleta_portada.
// Parte del flujo: reproductor (modal de cola, fondo).
// ─────────────────────────────────────────────────────────────

part of 'modal_cola.dart';

/// Carátula desenfocada que llena el fondo del modal de cola.
/// En modo Spotify, muestra color dominante sólido en su lugar.
Widget _fondoCaratulaCola(String? caratula, bool esOscuro) {
  if (caratula == null || caratula.isEmpty) {
    return const SizedBox.shrink();
  }
  final perfil = sl<ValueNotifier<PerfilRendimiento>>().value;
  return _FondoColaEstilo(
    caratula: caratula,
    esOscuro: esOscuro,
    sigma: perfil.sigmaDesenfoque,
  );
}

/// Widget que reacciona al estilo visual para mostrar blur o color dominante.
class _FondoColaEstilo extends StatefulWidget {
  final String caratula;
  final bool esOscuro;
  final double sigma;

  const _FondoColaEstilo({
    required this.caratula,
    required this.esOscuro,
    required this.sigma,
  });

  @override
  State<_FondoColaEstilo> createState() => _FondoColaEstiloState();
}

class _FondoColaEstiloState extends State<_FondoColaEstilo> {
  Color? _acento;

  @override
  void initState() {
    super.initState();
    _extraerColor();
  }

  @override
  void didUpdateWidget(covariant _FondoColaEstilo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caratula != widget.caratula) _extraerColor();
  }

  Future<void> _extraerColor() async {
    try {
      final paleta = await paletaParaPortada(widget.caratula);
      if (mounted) setState(() => _acento = paleta?.dominante);
    } catch (e) { debugPrint("[Feature] $e"); }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstiloVisual>(
      valueListenable: sl<ValueNotifier<EstiloVisual>>(),
      builder: (context, estilo, _) {
        return ValueListenableBuilder<PreferenciasEstilo>(
          valueListenable: sl<ValueNotifier<PreferenciasEstilo>>(),
          builder: (context, prefs, _) {
            final spotify = estilo == EstiloVisual.spotify && prefs.fondosModals;
            if (spotify) {
              final defaultBg =
                  widget.esOscuro ? const Color(0xFF141414) : const Color(0xFFF6F6F6);
              final colorBase = _acento ?? defaultBg;
              final colorFinal = Color.lerp(
                defaultBg,
                colorBase,
                widget.esOscuro ? 0.45 : 0.30,
              )!;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                color: colorFinal,
              );
            }
            return ClipRRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: widget.sigma,
                  sigmaY: widget.sigma,
                ),
                child: Transform.scale(
                  scale: 1.3,
                  child: imagenDesdeUrl(
                    widget.caratula,
                    ajuste: BoxFit.cover,
                    ancho: 512,
                    alto: double.infinity,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
