// ─────────────────────────────────────────────────────────────
// hoja_letras_fondo.dart — PART de hoja_letras.dart: fondo del
// modal de letras — carátula desenfocada con el sigma según el
// perfil de rendimiento.
// En modo Spotify, reemplaza el blur por color dominante sólido.
// Se conecta con: hoja_letras.dart (misma library) + imagen_portada
// + perfil_rendimiento + estilo_helper + paleta_portada.
// Parte del flujo: reproductor (letras, fondo).
// ─────────────────────────────────────────────────────────────

part of 'hoja_letras.dart';

/// Carátula desenfocada que llena el fondo del modal.
/// En modo Spotify, muestra color dominante sólido en su lugar.
Widget _fondoCaratula(String? caratula, bool esOscuro) {
  if (caratula == null || caratula.isEmpty) {
    return const SizedBox.shrink();
  }
  final perfil = sl<ValueNotifier<PerfilRendimiento>>().value;
  return _FondoLetrasEstilo(
    caratula: caratula,
    esOscuro: esOscuro,
    sigma: perfil.sigmaDesenfoque,
  );
}

/// Widget que reacciona al estilo visual para mostrar blur o color dominante.
class _FondoLetrasEstilo extends StatefulWidget {
  final String caratula;
  final bool esOscuro;
  final double sigma;

  const _FondoLetrasEstilo({
    required this.caratula,
    required this.esOscuro,
    required this.sigma,
  });

  @override
  State<_FondoLetrasEstilo> createState() => _FondoLetrasEstiloState();
}

class _FondoLetrasEstiloState extends State<_FondoLetrasEstilo> {
  Color? _acento;

  @override
  void initState() {
    super.initState();
    _extraerColor();
  }

  @override
  void didUpdateWidget(covariant _FondoLetrasEstilo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caratula != widget.caratula) _extraerColor();
  }

  Future<void> _extraerColor() async {
    try {
      final paleta = await paletaParaPortada(widget.caratula);
      if (mounted) setState(() => _acento = paleta?.dominante);
    } catch (_) {}
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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
