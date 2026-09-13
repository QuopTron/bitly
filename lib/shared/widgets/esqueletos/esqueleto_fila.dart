// ─────────────────────────────────────────────────────────────
// esqueleto_fila.dart — PART de esqueleto_carga.dart: fila shimmer
// animada usada por EsqueletoFeed — rectángulo con gradiente
// barrido que pulsa (track: 72px alto con radio 18; portada/otra:
// 220px con radio 16). Cada fila tiene su propio controlador.
// Se conecta con: esqueleto_carga.dart (misma library) + nada más.
// Parte del flujo: feed (loading de listas).
// ─────────────────────────────────────────────────────────────

part of 'esqueleto_carga.dart';

class _FilaEsqueleto extends StatefulWidget {
  final bool esTrack;
  final Color base;
  final Color brillo;

  const _FilaEsqueleto({
    required this.esTrack,
    required this.base,
    required this.brillo,
  });

  @override
  State<_FilaEsqueleto> createState() => _FilaEsqueletoState();
}

class _FilaEsqueletoState extends State<_FilaEsqueleto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alto = widget.esTrack ? 72.0 : 220.0;
    final radio = widget.esTrack ? 18.0 : 16.0;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          height: alto,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radio),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
              end: Alignment(-0.5 + 2.0 * _ctrl.value, 0),
              colors: [widget.base, widget.brillo, widget.base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}