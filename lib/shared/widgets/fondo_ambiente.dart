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
import '../../core/modelos/estilo_visual.dart';
import '../../core/modelos/perfil_rendimiento.dart';
import '../../core/modelos/preferencias_estilo.dart';
import '../../estado/cubit_cola.dart';
import '../../estado/cubit_like.dart';
import '../tema/colores_app.dart';
import '../utilidades/paleta_portada.dart';
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
/// En modo Spotify, reemplaza el cover por el color dominante del album.
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
    return ValueListenableBuilder<EstiloVisual>(
      valueListenable: sl<ValueNotifier<EstiloVisual>>(),
      builder: (context, estilo, _) {
        return ValueListenableBuilder<PreferenciasEstilo>(
          valueListenable: sl<ValueNotifier<PreferenciasEstilo>>(),
          builder: (context, prefs, _) {
            final url = coverUrl;
            final sigma =
                sl<ValueNotifier<PerfilRendimiento>>().value.sigmaDesenfoque;
            final spotify =
                estilo == EstiloVisual.spotify && prefs.fondoPrincipal;

            return RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Capa 1: cover borroso (solo en modo Clásico).
                  if (!spotify && url != null && url.isNotEmpty)
                    ClipRect(
                      child: ImageFiltered(
                        imageFilter:
                            ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                        child: Transform.scale(
                          scale: 1.25,
                          child: imagenDesdeUrl(
                            url,
                            ajuste: BoxFit.cover,
                            ancho: 512,
                            alto: double.infinity,
                          ),
                        ),
                      ),
                    )
                  else
                    ColoredBox(color: bgColor),
                  // Capa 2: velo — en Spotify usa color dominante.
                  if (spotify && url != null && url.isNotEmpty)
                    _VeloDinamico(
                      coverUrl: url,
                      isDark: isDark,
                      defaultBg: bgColor,
                    )
                  else
                    ColoredBox(
                      color: bgColor.withValues(alpha: isDark ? 0.66 : 0.42),
                    ),
                  // Capa 3: gradiente inferior para legibilidad.
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
          },
        );
      },
    );
  }
}

/// Velo dinámico que extrae el color dominante del cover y lo muestra
/// como fondo sólido en modo Spotify. Transición animada al cambiar.
class _VeloDinamico extends StatefulWidget {
  final String coverUrl;
  final bool isDark;
  final Color defaultBg;

  const _VeloDinamico({
    required this.coverUrl,
    required this.isDark,
    required this.defaultBg,
  });

  @override
  State<_VeloDinamico> createState() => _VeloDinamicoState();
}

class _VeloDinamicoState extends State<_VeloDinamico> {
  Color? _acento;

  @override
  void initState() {
    super.initState();
    _extraerColor();
  }

  @override
  void didUpdateWidget(covariant _VeloDinamico oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl) {
      _extraerColor();
    }
  }

  Future<void> _extraerColor() async {
    try {
      final paleta = await paletaParaPortada(widget.coverUrl);
      if (mounted) {
        setState(() {
          _acento = paleta?.dominante;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colorBase = _acento ?? widget.defaultBg;
    // Mezcla el color dominante con el fondo del tema para que no
    // sobresature pero sea claramente visible.
    final colorFinal = Color.lerp(
      widget.defaultBg,
      colorBase,
      widget.isDark ? 0.45 : 0.30,
    )!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      color: colorFinal,
    );
  }
}