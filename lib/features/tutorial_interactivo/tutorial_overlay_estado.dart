// tutorial_overlay_estado.dart — PART de tutorial_overlay.dart: el estado del
// overlay (fade de cada paso, latido del agujero y rastreo del objetivo).
//
// El rastreo importa: el objetivo se MUEVE solo (cambio de pestaña, scroll,
// entrada del miniplayer). Sin volver a medirlo, el agujero quedaría congelado
// en la posición del primer frame.
//
// Se conecta con: tutorial_overlay (misma library) + tutorial_controller.
// Parte del flujo: tutorial interactivo (estado de la capa).
part of 'tutorial_overlay.dart';

class _TutorialOverlayState extends State<TutorialOverlay>
    with TickerProviderStateMixin {
  /// Fade de entrada de cada paso.
  late final AnimationController _fade;

  /// Latido del borde del agujero (efecto "mirá acá").
  late final AnimationController _pulso;

  /// Rastrea dónde está el objetivo mientras el tutorial está abierto.
  /// El objetivo se mueve solo: al cambiar de pestaña, al hacer scroll o
  /// al entrar el miniplayer. Sin esto el agujero quedaría congelado en
  /// la posición del primer frame.
  Timer? _rastreador;

  /// Último rect medido, para no repintar si no cambió nada.
  Rect? _ultimoRect;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..forward();
    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    widget.controller.addListener(_alCambiarEstado);
    if (widget.controller.visible) _iniciarRastreador();
  }

  @override
  void didUpdateWidget(covariant TutorialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_alCambiarEstado);
      widget.controller.addListener(_alCambiarEstado);
    }
  }

  @override
  void dispose() {
    _rastreador?.cancel();
    widget.controller.removeListener(_alCambiarEstado);
    _fade.dispose();
    _pulso.dispose();
    super.dispose();
  }

  /// Arranca (una sola vez) la medición periódica del objetivo.
  void _iniciarRastreador() {
    _rastreador ??= Timer.periodic(
      const Duration(milliseconds: 220),
      (_) => _medirObjetivo(),
    );
  }

  /// Vuelve a medir el objetivo y repinta solo si se movió de verdad.
  void _medirObjetivo() {
    if (!mounted) return;
    final rect = rectDeObjetivo(widget.controller.pasoActual?.targetKey);
    if (rect == _ultimoRect) return;
    setState(() => _ultimoRect = rect);
  }

  /// El overlay se redibuja solo cuando el controller cambia: así no depende de
  /// que el shell que lo monta también se reconstruya (y se puede probar sin
  /// ese shell). Con cada paso nuevo reentra con fade, porque si no el texto
  /// cambia de golpe.
  void _alCambiarEstado() {
    if (!mounted) return;
    if (widget.controller.indiceActual != _indiceMostrado) {
      _indiceMostrado = widget.controller.indiceActual;
      // El paso nuevo puede apuntar a otro widget: se remide en el
      // próximo tick en vez de arrastrar la posición del anterior.
      _ultimoRect = null;
      _fade
        ..value = 0
        ..forward();
    }
    if (widget.controller.visible) {
      _iniciarRastreador();
    } else {
      _rastreador?.cancel();
      _rastreador = null;
    }
    setState(() {});
  }

  /// Índice que ya se está mostrando (para saber cuándo reentrar con fade).
  int _indiceMostrado = -1;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (!controller.visible || controller.pasoActual == null) {
      return const SizedBox.shrink();
    }

    // El objetivo se mide en cada build (y el rastreador avisa cuando se
    // movió) para que el agujero siga al widget durante las animaciones.
    //
    // El FocusScope con autofocus recibe el foco al montarse: en TV el D-pad
    // y en PC el Tab arrancan DENTRO de la tarjeta (y con el contenido de
    // atrás apartado por el host, no se les escapa a botones tapados).
    return FocusScope(
      autofocus: true,
      child: _CapasTutorial(
        fade: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
        pulso: _pulso,
        controller: controller,
        objetivo: rectDeObjetivo(controller.pasoActual!.targetKey),
        esOscuro: Theme.of(context).brightness == Brightness.dark,
      ),
    );
  }
}
