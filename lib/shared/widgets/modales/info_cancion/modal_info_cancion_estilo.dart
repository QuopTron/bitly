// ─────────────────────────────────────────────────────────────
// modal_info_cancion_estilo.dart — PART de modal_info_cancion.dart:
// envoltorio del modal de info de canción.
//
// Antes extraía su propio color dominante y aplicaba su propio
// tinte/desenfoque (distinto del karaoke o la cola). Ahora el fondo lo
// pone la hoja con el widget compartido FondoReactivoPortada, así todos
// los modales se ven igual.
// Se conecta con: modal_info_cancion.dart (misma library) +
// info_cancion_hoja.
// Parte del flujo: Reproductor → info de canción (estilo visual).
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
  );
}
