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
// El velo y la carátula se cruzan 1:1 con el control de intensidad (cada
// porcentaje vale lo mismo de punta a punta) y la carátula se va
// desenfocando a medida que sube, así se disuelve en el color del cover.
// Se conecta con: imagen_portada (helpers) + perfil_rendimiento +
// preferencias_estilo + estilo_helper + inyeccion (notifiers globales).
// Parte del flujo: Home (shell móvil/escritorio) — fondo global.
// ─────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/inyeccion/inyeccion.dart';
import '../../../../core/modelos/usuario/perfil/perfil_rendimiento.dart';
import '../../../../core/modelos/usuario/preferencias/preferencias_estilo.dart';
import '../../../utilidades/formato/comun/formato/estilo_helper.dart';
import '../../../utilidades/plataforma/pantalla/efectos_app.dart';
import '../../tarjetas/portada/imagen_portada.dart';
import '../../vidrio/base/desenfoque_adaptativo.dart';
import 'atenuado_por_nivel.dart';
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
    return ValueListenableBuilder<PreferenciasEstilo>(
      valueListenable: sl<ValueNotifier<PreferenciasEstilo>>(),
      builder: (context, prefs, _) {
        final url = coverUrl;
        // El blur de este fondo es a PANTALLA COMPLETA y se recompone en
        // cada frame: es lo más caro de la app. En gama baja se pinta el
        // cover sin desenfocar (una sola textura) y el velo mantiene la
        // legibilidad; el desenfoque solo se acota al tope del perfil.
        final sigmaBase = math.min(
          sl<ValueNotifier<PerfilRendimiento>>().value.sigmaDesenfoque,
          EfectosApp.sigmaMaximo.value,
        );
        // Intensidad del cover en el fondo: 0 = cover difuminado con
        // velo del tema (el de siempre), 1 = sólo el color dominante.
        // En el medio se cruzan las tres capas, lineales con el control: el
        // 50% deja la carátula a medio apagar y el color a media entrada.
        //
        // En MODO FLUIDO se salta la foto a pantalla completa (la capa más
        // cara por frame en una GPU de gama baja) y se va directo al color
        // dominante: es el mismo estado al que llega este control al 100%, así
        // que el diseño y el color de la canción se mantienen.
        final fluido = !EfectosApp.fotoPantallaCompletaActiva;
        final v = fluido ? 1.0 : prefs.fondoPrincipal;
        // Y la carátula se va DESENFOCANDO con la intensidad: con 1% está casi
        // nítida y en el extremo ya no se distingue del color del cover, así se
        // disuelve en vez de apagarse como una foto.
        final sigma = EstiloHelper.sigmaPorNivel(sigmaBase, v);
        // El velo también se aclara con la intensidad: es lo que hace que
        // cada porcentaje se note en la carátula antes de que el color la
        // tape del todo.
        final velo = EstiloHelper.mezclar(
          isDark ? 0.66 : 0.42,
          isDark ? 0.34 : 0.22,
          v,
        );

        return RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Capa 0: base opaca (nunca se ve el fondo de la página).
              ColoredBox(color: bgColor),
              // Capa 1: cover de fondo (con blur solo si el perfil lo
              // permite; sin él es una sola textura). Se apaga a medida que
              // entra el color del cover, y en modo fluido no se pinta.
              if (!fluido && url != null && url.isNotEmpty)
                AtenuadoPorNivel(
                  opacidad: 1 - v,
                  child: ClipRect(
                    // El desenfoque del fondo con su tope propio: el del perfil
                    // es el del diseño de fábrica y acá hay margen por encima.
                    child: DesenfoqueHijo(
                      sigma: sigma,
                      tope: EstiloHelper.topeSigma(sigmaBase),
                      child: _CoverFondo(url: url),
                    ),
                  ),
                ),
              // Capa 2: velo del tema (legibilidad del texto).
              ColoredBox(color: bgColor.withValues(alpha: velo)),
              // Capa 3: color dominante del cover, encima del velo y
              // entrando de a poco con la intensidad.
              if (url != null && url.isNotEmpty)
                AtenuadoPorNivel(
                  opacidad: v,
                  child: VeloDinamico(
                    coverUrl: url,
                    isDark: isDark,
                    defaultBg: bgColor,
                  ),
                ),
              // Capa 4: gradiente inferior para legibilidad.
              // `DecoratedBox` en vez de `Container`: un Container de sólo
              // decoración arma igual el DecoratedBox pero además pasa por
              // LayoutBuilder/ConstrainedBox y su Padding al medir. Mismos
              // píxeles, menos widgets por frame.
              DecoratedBox(
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
  }
}

/// Cover del fondo ambiente: escalado 1.25.
///
/// El desenfoque lo pone `DesenfoqueHijo`, que ya separa el caso "con blur" del
/// "sin blur": en gama baja devuelve la imagen tal cual y la GPU no paga un
/// `ImageFiltered` a pantalla completa.
class _CoverFondo extends StatelessWidget {
  final String url;

  const _CoverFondo({required this.url});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 1.25,
      child: imagenDesdeUrl(
        url,
        ajuste: BoxFit.cover,
        ancho: 512,
        alto: double.infinity,
      ),
    );
  }
}
