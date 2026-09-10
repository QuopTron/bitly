// ─────────────────────────────────────────────────────────────
// selector_velocidad_reproductor.dart — Selector de velocidad de
// reproducción del NowPlaying: etiqueta con el valor actual (tap
// para resetear a 1.0×) y una fila de chips 0.5×–2.0× donde el
// activo se resalta. Despacha el cambio al cubit del reproductor.
// Se conecta con: cubit_reproductor + responsive.
// Parte del flujo: reproductor (NowPlaying, velocidad).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/cache/estado_reproductor.dart';
import '../../estado/cubit_reproductor.dart';
import '../../shared/utilidades/responsive.dart';

/// Chips de velocidad 0.5×–2.0× con el valor actual.
class SelectorVelocidadReproductor extends StatelessWidget {
  final Responsive r;
  final bool esOscuro;
  final EstadoAudioReproductor estado;

  const SelectorVelocidadReproductor({
    super.key,
    required this.r,
    required this.esOscuro,
    required this.estado,
  });

  @override
  Widget build(BuildContext context) {
    const velocidades = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final activo = esOscuro ? Colors.white : Colors.black;
    final inactivo = activo.withValues(alpha: 0.4);

    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.speed_rounded, size: r.subtitleSize, color: inactivo),
            SizedBox(width: r.spacingS),
            Text(
              'Speed',
              style: TextStyle(
                fontSize: r.footerSize,
                letterSpacing: 0.4,
                color: inactivo,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () =>
                  context.read<CubitReproductor>().setVelocidad(1.0),
              child: Text(
                estado.velocidad == 1.0
                    ? '1.0×'
                    : '${_formatearVelocidad(estado.velocidad)}×',
                style: TextStyle(
                  fontSize: r.footerSize,
                  fontWeight: FontWeight.w600,
                  color:
                      estado.velocidad == 1.0 ? activo : inactivo,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: r.spacingXS),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final s in velocidades) ...[
              if (s != velocidades.first) const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      context.read<CubitReproductor>().setVelocidad(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: (estado.velocidad == s
                              ? activo
                              : Colors.transparent)
                          .withValues(
                              alpha: estado.velocidad == s ? 0.12 : 0.0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: estado.velocidad == s
                            ? activo.withValues(alpha: 0.3)
                            : activo.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      '${_formatearVelocidad(s)}×',
                      style: TextStyle(
                        fontSize: r.footerSize - 1,
                        fontWeight: estado.velocidad == s
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: estado.velocidad == s ? activo : inactivo,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Formatea 1.0 → 1, 1.25 → 1.25, 0.75 → 0.75.
  String _formatearVelocidad(double v) {
    return v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(
        RegExp(r'\.$'), '');
  }
}