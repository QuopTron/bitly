// ─────────────────────────────────────────────────────────────
// volumen_reproductor.dart — CONTROL DE VOLUMEN del reproductor.
//
// Lo usan SOLO las variantes de PC y TV (ver vistas/reproductor_escritorio y
// vistas/reproductor_tv). En el celular NO va a propósito: ahí el volumen lo
// manejan las teclas del propio aparato, y duplicarlo en pantalla sería ruido
// —dos volúmenes distintos, el del sistema y el de la app—. Por eso este
// archivo vive aparte del resto de los controles: deja clarísimo quién lo usa.
//
// Es un botón de silencio + deslizador + porcentaje. El volumen vive en el
// estado del reproductor (CubitReproductor) y sobrevive a los crossfades, que
// mueven el volumen real del player sin tocar el del usuario.
//
// Se conecta con: CubitReproductor (setVolumen / alternarSilencio) + l10n.
// Parte del flujo: reproductor (variantes PC y TV).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/cache/estado/estado_reproductor.dart';
import '../../../../estado/reproductor/cubit_reproductor.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/tema/especificaciones/especificaciones_plataforma.dart';
import '../../../../shared/utilidades/plataforma/responsive.dart';

/// Fila de volumen: silencio, deslizador y porcentaje.
class VolumenReproductor extends StatelessWidget {
  /// Ancho del deslizador. La TV, que se maneja a metros, usa uno más ancho.
  final double anchoDeslizador;

  const VolumenReproductor({super.key, this.anchoDeslizador = 160});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context).reproductor;
    // El control se mide con el aparato: se usa sólo en PC y TV, así que el
    // ancho del porcentaje y su texto tienen que crecer en la tele.
    final r = Responsive(context);
    final esp = EspecificacionesPlataforma.de(context);
    final activo =
        Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black;
    return BlocBuilder<CubitReproductor, EstadoAudioReproductor>(
      buildWhen: (prev, curr) => prev.volumen != curr.volumen,
      builder: (context, estado) {
        final cubit = context.read<CubitReproductor>();
        final volumen = estado.volumen.clamp(0.0, 1.0);
        final silenciado = volumen <= 0.001;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: loc.volumen,
              icon: Icon(
                silenciado ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: activo.withValues(alpha: 0.85),
              ),
              onPressed: cubit.alternarSilencio,
            ),
            SizedBox(
              width: anchoDeslizador,
              child: Slider(value: volumen, onChanged: cubit.setVolumen),
            ),
            SizedBox(
              width: r.sobre(46, 66),
              child: Text(
                '${(volumen * 100).round()}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: esp.textoEtiqueta,
                  color: activo.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
