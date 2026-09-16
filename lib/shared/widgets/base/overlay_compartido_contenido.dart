// ─────────────────────────────────────────────────────────────
// overlay_compartido_contenido.dart — Cuerpo del overlay "te
// compartieron": detrás solo se DESENFOCA la app (sin taparla), y en
// el centro va una carta CHICA del ítem.
//
// Dos formas de carta: canción → una fila compacta con su carátula;
// álbum/artista/playlist → una mini tarjeta de grilla. Abajo, las
// dos opciones (principal + omitir). Nada ocupa la pantalla: se ve la
// app detrás y la carta queda flotando en el medio, chica, incluso en
// PC o tablet (tope de 380 px de ancho).
//
// Parts: _fondo (desenfoque), _encabezado, _tarjeta, _arte, _acciones.
//
// Se conecta con: overlay_compartido.dart (lo monta) + ItemFeed +
// AppLocalizations + Responsive + ImagenPortada.
// Parte del flujo: enlace compartido → carta → reproducir/encolar.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/modelos/feed/item_feed.dart';
import '../../../l10n/app_localizations.dart';
import '../../utilidades/plataforma/efectos_app.dart';
import '../../utilidades/plataforma/responsive.dart';
import '../tarjetas/portada/imagen_portada.dart';
import '../vidrio/desenfoque_adaptativo.dart';

part 'overlay_compartido_fondo.dart';
part 'overlay_compartido_encabezado.dart';
part 'overlay_compartido_tarjeta.dart';
part 'overlay_compartido_arte.dart';
part 'overlay_compartido_tipo.dart';
part 'overlay_compartido_acciones.dart';

/// Contenido del overlay: encabezado + carta chica + opciones.
class OverlayCompartidoContenido extends StatelessWidget {
  final ItemFeed item;

  /// Nombre de quien manda el enlace (vacío en enlaces viejos).
  final String emisor;

  /// Código ISRC: la identidad exacta de la canción.
  final String isrc;

  final String type;

  /// Avance de la entrada (0 → 1).
  final double progreso;

  /// true cuando ya hay algo sonando: la acción principal pasa a
  /// "agregar a la cola".
  final bool enCola;

  /// Si false, no pinta el fondo: lo pone el dueño (así el desenfoque no
  /// se reconstruye en cada frame de la animación de entrada).
  final bool mostrarFondo;

  /// Acción principal: reproducir o encolar, según [enCola].
  final VoidCallback onAccion;
  final VoidCallback onDismiss;

  const OverlayCompartidoContenido({
    super.key,
    required this.item,
    required this.emisor,
    required this.isrc,
    required this.type,
    required this.progreso,
    required this.onAccion,
    required this.onDismiss,
    this.enCola = false,
    this.mostrarFondo = true,
  });

  /// Caída de la carta: llega desde arriba y se asienta antes de la mitad.
  double get _caida =>
      Curves.easeOutCubic.transform((progreso / 0.7).clamp(0.0, 1.0));

  /// Aparición de los textos y las opciones.
  double get _aparece =>
      Curves.easeOut.transform(((progreso - 0.15) / 0.5).clamp(0.0, 1.0));

  /// Desplazamiento vertical: solo la caída corta de entrada.
  double get _desplazamiento => (1 - _caida) * -26;

  /// Escala de entrada: 0.94 → 1.
  double get _escala => 0.94 + 0.06 * _caida;

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final l = AppLocalizations.of(context).setup;
    final cs = Theme.of(context).colorScheme;
    final esTrack = type == 'track';

    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        if (mostrarFondo)
          Positioned.fill(child: FondoCompartido(onDismiss: onDismiss)),
        Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: r.spacingXL,
              vertical: r.spacingXL,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: _aparece,
                    child: _cabeceraOverlay(cs, this, r, l),
                  ),
                  SizedBox(height: r.spacingL),
                  Transform.translate(
                    offset: Offset(0, _desplazamiento),
                    child: Transform.scale(
                      scale: _escala,
                      // Absorbe los toques sobre la carta: solo cierran los
                      // botones de abajo, no un toque en el borde de la placa.
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {},
                        child:
                            esTrack
                                ? _tarjetaTrackMini(cs, this, r, l)
                                : _tarjetaGridMini(cs, this, r, l),
                      ),
                    ),
                  ),
                  SizedBox(height: r.spacingL),
                  Opacity(
                    opacity: _aparece,
                    child: _accionesOverlay(cs, this, r, l),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
