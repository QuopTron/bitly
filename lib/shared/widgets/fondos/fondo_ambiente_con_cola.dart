// ─────────────────────────────────────────────────────────────
// fondo_ambiente_con_cola.dart — Fondo ambiente atado a la reproducción:
// lee la canción ACTUAL de CubitCola y la mejor carátula local
// (caratulaLocalPara de CubitLikes, igual que los modals) y arma el
// Stack con FondoAmbiente detrás del contenido.
// Se conecta con: fondo_ambiente (la capa visual) + cubit_cola +
// cubit_like + colores_app.
// Parte del flujo: Home (shell móvil/escritorio) — fondo global.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cache/estado/estado_cola.dart';
import '../../../estado/cola/cubit_cola.dart';
import '../../../estado/like/cubit_like.dart';
import '../../tema/colores_app.dart';
import 'fondo_ambiente.dart';

/// Fondo con el cover de la canción actual envuelve [child].
/// Lee CubitCola (canción actual) y CubitLikes (mejor carátula local).
class FondoAmbienteConCola extends StatelessWidget {
  final Widget child;

  const FondoAmbienteConCola({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CubitCola, EstadoCola>(
      builder: (context, estado) {
        final track = estado.actual;
        String? cover;
        if (track != null) {
          try {
            cover = context.read<CubitLikes>().caratulaLocalPara(track) ??
                track.coverUrl;
          } catch (_) {
            cover = track.coverUrl;
          }
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            FondoAmbiente(
              coverUrl: cover,
              isDark: Theme.of(context).brightness == Brightness.dark,
              bgColor: Theme.of(context).brightness == Brightness.dark
                  ? ColoresApp.fondoOscuro
                  : ColoresApp.fondoClaro,
            ),
            child,
          ],
        );
      },
    );
  }
}
