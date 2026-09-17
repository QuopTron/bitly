// ─────────────────────────────────────────────────────────────
// router_enlaces_test.dart — Fija el arreglo del enlace compartido:
// una URL entrante (la forma en que llega en web/PWA y en el
// navegador) tiene que terminar en el home con la carta registrada,
// NUNCA en la pantalla de error de go_router.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/core/modelos/feed/item_feed.dart';
import 'package:bitly/core/plataforma/sistema/servicio_deep_link.dart';
import 'package:bitly/core/servicios/compartir/datos_compartido.dart';
import 'package:bitly/core/servicios/compartir/servicio_compartir.dart';
import 'package:bitly/router/app_router_enlaces.dart';
import 'package:bitly/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

const _cancion = ItemFeed(
  id: 'spotify:track:5TFD2bmFKGhoCRbX61nXY5',
  type: 'track',
  name: 'NUEVAYoL',
  artists: 'Bad Bunny',
  albumName: 'DeBÍ TiRAR MáS FOToS',
  durationMs: 183685,
  isrc: 'USUM72500857',
);

void main() {
  final enlace = ServicioCompartir.instance.construirEnlace(
    DatosCompartido.desdeItem(_cancion, emisor: 'Pablo'),
  );

  test('la URL completa del compartido entra al home', () {
    expect(destinoDeLocationExterna(enlace), RouteNames.home.path);
  });

  test('la ruta relativa /open?s=... (web) también entra al home', () {
    final relativa = Uri.parse(enlace).toString().replaceFirst(
          'https://${ServicioCompartir.host}',
          '',
        );
    expect(relativa, startsWith('/open?s='));
    expect(destinoDeLocationExterna(relativa), RouteNames.home.path);
  });

  test('el payload queda como carta pendiente al abrir la app', () {
    ServicioDeepLink.instance.consumirPendiente();
    destinoDeLocationExterna(enlace);
    final pendiente = ServicioDeepLink.instance.linkPendiente;
    expect(pendiente, isNotNull);
    expect(pendiente!.compartido?.isrc, 'USUM72500857');
    expect(pendiente.query, 'NUEVAYoL');
  });

  test('las rutas internas no se tocan', () {
    for (final ruta in ['/', '/setup', '/home', '/tutorial']) {
      expect(destinoDeLocationExterna(ruta), isNull);
    }
  });

  test('un enlace desconocido va al home igual (sin pantalla de error)', () {
    expect(destinoDeLocationExterna('/open?s=basura'), RouteNames.home.path);
    expect(destinoDeLocationExterna('https://otro-sitio.test/x'), RouteNames.home.path);
    expect(destinoDeLocationExterna('/cualquier/cosa'), RouteNames.home.path);
  });

  test('un enlace manipulado no deja carta pendiente', () {
    ServicioDeepLink.instance.consumirPendiente();
    destinoDeLocationExterna('/open?s=basura');
    expect(ServicioDeepLink.instance.linkPendiente, isNull);
  });
}
