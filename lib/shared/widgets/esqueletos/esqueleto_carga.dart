// ─────────────────────────────────────────────────────────────
// esqueleto_carga.dart — Esqueletos de carga shimmer (animación
// de gradiente pulsante sobre formas placeholder) para dar un
// feel premium mientras cargan los datos. Aquí viven el bloque
// base EsqueletoCarga, el esqueleto de feed completo y el de
// detalle (portada circular + fila). La fila animada vive en el
// part esqueleto_fila.dart y la variante de búsqueda en
// esqueleto_busqueda.dart.
// Se conecta con: nada (solo tema del context).
// Parte del flujo: feed, detalle, búsqueda (loading).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

part 'esqueleto_fila.dart';

/// Bloque shimmer base: gradiente pulsante sobre una forma redondeada.
class EsqueletoCarga extends StatefulWidget {
  final double ancho;
  final double alto;
  final double radioBorde;

  const EsqueletoCarga({
    super.key,
    this.ancho = double.infinity,
    this.alto = 16,
    this.radioBorde = 8,
  });

  @override
  State<EsqueletoCarga> createState() => _EsqueletoCargaState();
}

class _EsqueletoCargaState extends State<EsqueletoCarga>
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
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final base = oscuro
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);
    final brillo = oscuro
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          width: widget.ancho,
          height: widget.alto,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radioBorde),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
              end: Alignment(-0.5 + 2.0 * _ctrl.value, 0),
              colors: [base, brillo, base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Esqueleto de página completa para feed / carga de listas.
class EsqueletoFeed extends StatelessWidget {
  const EsqueletoFeed({super.key});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final base = oscuro
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);
    final brillo = oscuro
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 8,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final esTrack = index % 3 != 2;
        return _FilaEsqueleto(
          esTrack: esTrack,
          base: base,
          brillo: brillo,
        );
      },
    );
  }
}

/// Esqueleto centrado para páginas de detalle (álbum, playlist, artista).
class EsqueletoDetalle extends StatelessWidget {
  const EsqueletoDetalle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EsqueletoCarga(
            ancho: 180,
            alto: 180,
            radioBorde: 90,
          ),
          const SizedBox(height: 24),
          EsqueletoCarga(ancho: 260, alto: 220, radioBorde: 16),
        ],
      ),
    );
  }
}