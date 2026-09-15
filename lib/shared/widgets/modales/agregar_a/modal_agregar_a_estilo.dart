// ─────────────────────────────────────────────────────────────
// modal_agregar_a_estilo.dart — PART de modal_agregar_a.dart: wrapper que reacciona al estilo visual (blur/color dominante) del modal agregar-a.
// Se conecta con: modal_agregar_a.dart (misma library) + estilo_helper + paleta_portada.
// Parte del flujo: Reproductor → agregar a (estilo visual).
// ─────────────────────────────────────────────────────────────

part of 'modal_agregar_a.dart';

// Widget wrapper that reacts to visual style for blur/dominant color.
class _AgregarAEstilo extends StatefulWidget {
  final bool esOscuro;
  final Color onBg;
  final Color bg;
  final bool hayTrack;
  final Color fondoModal;
  final Responsive r;
  final AppLocalizations loc;
  final ItemFeed item;

  const _AgregarAEstilo({
    required this.esOscuro,
    required this.onBg,
    required this.bg,
    required this.hayTrack,
    required this.fondoModal,
    required this.r,
    required this.loc,
    required this.item,
  });

  @override
  State<_AgregarAEstilo> createState() => _AgregarAEstiloState();
}

class _AgregarAEstiloState extends State<_AgregarAEstilo> {
  Color? _acento;

  @override
  void initState() {
    super.initState();
    _extraerColor();
  }

  Future<void> _extraerColor() async {
    final url = widget.item.coverUrl;
    if (url == null || url.isEmpty) return;
    try {
      final paleta = await paletaParaPortada(url);
      if (mounted) setState(() => _acento = paleta?.dominante);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => _construirHojaAgregarA(this, context);


  /// Abre el picker de playlists o el diálogo de creación si no hay ninguna.
  void _agregarAPlaylist(BuildContext context, ItemFeed item) {
    final cubit = sl<CubitPlaylists>();
    if (cubit.state.playlists.isEmpty) {
      _mostrarDialogoCrear(context, cubit, item);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _SelectorPlaylist(r: widget.r, cubit: cubit, item: item),
    );
  }
}
