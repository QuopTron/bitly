// ─────────────────────────────────────────────────────────────
// fondo_ambiente.dart — Fondo ambiente de la Home: el cover de la
// canción ACTUAL (resuelto con caratulaLocalPara del CubitLikes,
// igual que los modals) se pinta desenfocado y escalado detrás de
// todo el shell, con un velo del color de fondo del tema para
// mantener la legibilidad. Replica el AmbientBackdrop del diseño
// anterior y el tinte de los modals (_SongTintedBackground). El
// blur usa el sigma del perfil de rendimiento (menos sigma en modo
// bajo consumo) y el decode es acotado a 512px para que el blur
// full-screen sea barato en móvil.
// Se conecta con: imagen_portada (helpers) + perfil_rendimiento +
// cubit_cola + cubit_like + colores_app.
// Parte del flujo: Home (shell móvil/escritorio) — fondo global.
// ─────────────────────────────────────────────────────────────

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/inyeccion.dart';
import '../../core/cache/estado_cola.dart';
import '../../core/modelos/perfil_rendimiento.dart';
import '../../estado/cubit_cola.dart';
import '../../estado/cubit_like.dart';
import '../tema/colores_app.dart';
import 'imagen_portada.dart';

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

/// Capa de fondo: cover desenfocado + velo + gradiente inferior.
class FondoAmbiente extends StatelessWidget {
  final String? coverUrl;
  final bool isDark;
  final Color bgColor;

  const FondoAmbiente({
    super.key,
    required this.coverUrl,
    required this.isDark,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = coverUrl;
    final sigma = sl<ValueNotifier<PerfilRendimiento>>().value.sigmaDesenfoque;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url.isNotEmpty)
            ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: Transform.scale(
                  scale: 1.25,
                  child: imagenDesdeUrl(
                    url,
                    ajuste: BoxFit.cover,
                    // Decode acotado: el blur disimula el detalle y un origen
                    // pequeño mantiene el gaussian full-screen barato en móvil.
                    ancho: 512,
                    alto: double.infinity,
                  ),
                ),
              ),
            )
          else
            ColoredBox(color: bgColor),
          // Velo del tema: mantiene la página realmente oscura/clara.
          ColoredBox(
            color: bgColor.withValues(alpha: isDark ? 0.66 : 0.42),
          ),
          // Oscurecido extra abajo para que los controles sigan legibles.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  bgColor.withValues(alpha: isDark ? 0.35 : 0.25),
                ],
                stops: const [0.6, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}