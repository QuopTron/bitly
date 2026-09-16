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
// FondoAmbienteConCola (la variante atada a la cola) vive en
// fondo_ambiente_con_cola.dart y se re-exporta acá.
// Se conecta con: imagen_portada (helpers) + perfil_rendimiento +
// preferencias_estilo + inyeccion (notifiers globales).
// Parte del flujo: Home (shell móvil/escritorio) — fondo global.
// ─────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../app/inyeccion.dart';
import '../../../core/modelos/usuario/estilo_visual.dart';
import '../../../core/modelos/usuario/perfil_rendimiento.dart';
import '../../../core/modelos/usuario/preferencias_estilo.dart';
import '../../utilidades/plataforma/efectos_app.dart';
import '../tarjetas/portada/imagen_portada.dart';
import 'fondo_ambiente_velo.dart';

export 'fondo_ambiente_con_cola.dart';

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
            // El blur de este fondo es a PANTALLA COMPLETA y se recompone en
            // cada frame: es lo más caro de la app. En gama baja se pinta el
            // cover sin desenfocar (una sola textura) y el velo mantiene la
            // legibilidad; el desenfoque solo se acota al tope del perfil.
            final sigma = math.min(
              sl<ValueNotifier<PerfilRendimiento>>().value.sigmaDesenfoque,
              EfectosApp.sigmaMaximo.value,
            );
            final spotify =
                estilo == EstiloVisual.spotify && prefs.fondoPrincipal;

            return RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Capa 1: cover de fondo (con blur solo si el perfil lo
                  // permite; sin él es una sola textura, casi gratis).
                  if (!spotify && url != null && url.isNotEmpty)
                    ClipRect(child: _CoverFondo(url: url, sigma: sigma))
                  else
                    ColoredBox(color: bgColor),
                  // Capa 2: velo — en Spotify usa color dominante.
                  if (spotify && url != null && url.isNotEmpty)
                    VeloDinamico(
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

/// Cover del fondo ambiente: escalado 1.25 y desenfocado SOLO si [sigma] > 0.
///
/// Separa el caso "con blur" del "sin blur" para que la GPU no pague un
/// `ImageFiltered` a pantalla completa en los equipos de gama baja.
class _CoverFondo extends StatelessWidget {
  final String url;
  final double sigma;

  const _CoverFondo({required this.url, required this.sigma});

  @override
  Widget build(BuildContext context) {
    final cover = Transform.scale(
      scale: 1.25,
      child: imagenDesdeUrl(
        url,
        ajuste: BoxFit.cover,
        ancho: 512,
        alto: double.infinity,
      ),
    );
    if (sigma <= 0) return cover;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: cover,
    );
  }
}

