// ─────────────────────────────────────────────────────────────
// modal_info_cancion_estilo.dart — PART de modal_info_cancion.dart:
// envoltorio del modal de info de canción.
//
// Antes extraía su propio color dominante y aplicaba su propio
// tinte/desenfoque (distinto del karaoke o la cola). Ahora el fondo lo
// pone la hoja con el widget compartido FondoReactivoPortada, así todos
// los modales se ven igual.
//
// Acá vive además el ESTADO de la traducción de los datos: qué idioma
// eligió el usuario, si está traduciendo y el mapa valor original →
// valor traducido. Se guarda sólo en memoria durante la vida del modal
// (el servicio cachea por sesión, así que reabrirlo es instantáneo).
// Se conecta con: modal_info_cancion.dart (misma library) +
// info_cancion_hoja + servicio_traduccion_texto (vía inyección).
// Parte del flujo: Reproductor → info de canción (estilo + traducción).
// ─────────────────────────────────────────────────────────────

part of 'modal_info_cancion.dart';

/// Envoltorio del modal de info de canción.
class _InfoCancionEstilo extends StatefulWidget {
  final bool esOscuro;
  final Color bg;
  final Color onBg;
  final Color fondoModal;
  final Responsive r;
  final AppLocalizations loc;
  final ItemFeed item;
  final String duracion;

  const _InfoCancionEstilo({
    required this.esOscuro,
    required this.bg,
    required this.onBg,
    required this.fondoModal,
    required this.r,
    required this.loc,
    required this.item,
    required this.duracion,
  });

  @override
  State<_InfoCancionEstilo> createState() => _InfoCancionEstiloState();
}

class _InfoCancionEstiloState extends State<_InfoCancionEstilo> {
  /// Valor original → valor traducido. null = se está viendo el original.
  Map<String, String>? _traducciones;

  /// Idioma de origen que detectó el traductor (para mostrarlo).
  String? _idiomaOrigen;

  /// Idioma destino elegido (queda marcado en el selector).
  String? _idiomaDestino;

  bool _traduciendo = false;

  /// Textos que se traducen: los tres que son lenguaje. La fecha, el ISRC y
  /// el origen son datos y no entran (traducir un ISRC no significa nada).
  List<String> get _textos => [
    widget.item.name,
    widget.item.artists ?? '',
    widget.item.albumName ?? '',
  ];

  @override
  Widget build(BuildContext context) => _construirHojaInfoCancion(
    context: context,
    r: widget.r,
    onBg: widget.onBg,
    loc: widget.loc,
    item: widget.item,
    duracion: widget.duracion,
    fondoModal: widget.bg,
    esOscuro: widget.esOscuro,
    traducciones: _traducciones,
    traduciendo: _traduciendo,
    idiomaOrigen: _idiomaOrigen,
    onTraducir: _onTraducir,
  );

  /// El botón hace las dos cosas: si hay traducción la quita (volver al
  /// original) y si no, abre el selector de idioma.
  Future<void> _onTraducir() async {
    if (_traduciendo) return;
    if (_traducciones != null) {
      setState(() {
        _traducciones = null;
        _idiomaOrigen = null;
      });
      return;
    }
    final elegido = await _abrirSelectorIdiomaInfo(
      context,
      widget.loc,
      widget.esOscuro,
      _idiomaDestino,
    );
    if (!mounted || elegido == null) return;
    await _traducirA(elegido);
  }

  Future<void> _traducirA(String destino) async {
    setState(() {
      _traduciendo = true;
      _idiomaDestino = destino;
    });
    final textos = _textos;
    final res = await sl<ServicioTraduccionTexto>().traducir(
      textos: textos,
      destino: destino,
    );
    if (!mounted) return;
    setState(() {
      _traduciendo = false;
      if (res == null) {
        _traducciones = null;
        _idiomaOrigen = null;
        return;
      }
      final mapa = <String, String>{};
      for (var i = 0; i < textos.length; i++) {
        if (textos[i].trim().isNotEmpty) mapa[textos[i]] = res.textos[i];
      }
      _traducciones = mapa;
      _idiomaOrigen = res.idiomaOrigen;
    });
    if (res == null) {
      // El traductor gratuito puede fallar sin aviso: se dice, no se deja
      // el botón mudo (la hoja sigue mostrando los datos originales).
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(widget.loc.infoCancion.traduccionError),
          duration: const Duration(milliseconds: 1800),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }
}
