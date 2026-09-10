// ─────────────────────────────────────────────────────────────
// acordeon_fuente.dart — Selector compacto de fuente de búsqueda:
// botón circular con el icono de la fuente activa que abre un
// popup flotante (OverlayEntry) anclado bajo el botón. Usa overlay
// en vez de expansión inline para no empujar el layout. El panel
// flotante vive en el part acordeon_fuente_panel.dart.
// Se conecta con: constantes_fuente (iconos/etiquetas) + part panel.
// Parte del flujo: búsqueda (selector de extensión en la barra).
// ─────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constantes/constantes_fuente.dart';

part 'acordeon_fuente_panel.dart';
part 'acordeon_fuente_overlay.dart';

/// Fila del panel: valor del id de fuente + icono + etiqueta legible.
class FilaFuente {
  final String valor;
  final IconData icono;
  final String etiqueta;

  const FilaFuente(this.valor, this.icono, this.etiqueta);
}

/// Selector de fuente que abre un popup flotante anclado al botón.
class AcordeonFuente extends StatefulWidget {
  final Map<String, String> fuentes;
  final String fuenteSeleccionada;
  final Color onBg;
  final Color colorBrillo;
  final ValueChanged<String> onCambiada;

  const AcordeonFuente({
    super.key,
    required this.fuentes,
    required this.fuenteSeleccionada,
    required this.onBg,
    required this.colorBrillo,
    required this.onCambiada,
  });

  @override
  State<AcordeonFuente> createState() => _AcordeonFuenteState();
}

class _AcordeonFuenteState extends State<AcordeonFuente> {
  final GlobalKey _botonKey = GlobalKey();
  OverlayEntry? _entrada;
  bool _abierto = false;

  static const double _altoFila = 40;

  bool get _esOscuro => widget.onBg.computeLuminance() > 0.5;

  IconData get _iconoActual =>
      iconosFuente[widget.fuenteSeleccionada] ?? Icons.music_video;

  /// Wrapper público para que los parts puedan llamar setState.
  void _aplicar(VoidCallback fn) => setState(fn);

  @override
  void dispose() {
    _cerrarOverlay(desdeDispose: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: _botonKey,
      color: Colors.transparent,
      child: InkWell(
        onTap: _alternar,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.onBg.withValues(alpha: _esOscuro ? 0.08 : 0.06),
          ),
          child: Center(child: _iconoRedondeado(_iconoActual, tamano: 19)),
        ),
      ),
    );
  }

  void _alternar() {
    if (_abierto) {
      _cerrarOverlay();
    } else {
      _abrirOverlaySt(this);
    }
  }

  void _cerrarOverlay({bool desdeDispose = false}) {
    if (_entrada != null) {
      _entrada!.remove();
      _entrada = null;
    }
    if (!desdeDispose && _abierto && mounted) {
      setState(() => _abierto = false);
    }
  }

  List<FilaFuente> get _filas {
    // Respeta el orden de inserción del llamador (la config de búsqueda pone
    // la fuente primaria primero, p.ej. deezer) sin reordenar alfabéticamente.
    return [
      for (final e in widget.fuentes.entries)
        FilaFuente(e.key, iconosFuente[e.key] ?? Icons.music_video, e.value),
    ];
  }

  Widget _iconoRedondeado(IconData icono, {required double tamano, Color? tinte}) {
    final c = tinte ?? widget.onBg;
    return Container(
      width: tamano + 12,
      height: tamano + 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.08),
      ),
      child: Icon(icono, size: tamano, color: c.withValues(alpha: 0.95)),
    );
  }
}