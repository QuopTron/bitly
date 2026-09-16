// Test de `pasoElArranque`: define cuándo la app ya está usable, que es la
// condición para mostrar la carta "te compartieron" (y cualquier acción que
// dependa del backend). Falla si alguien cambia los paths de las rutas.

import 'package:bitly/router/route_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sin ruta resuelta todavía no está lista', () {
    expect(pasoElArranque(''), isFalse);
  });

  test('el splash no cuenta', () {
    expect(pasoElArranque(RouteNames.splash.path), isFalse);
    expect(pasoElArranque('/'), isFalse);
  });

  test('el setup tampoco (primera vez)', () {
    expect(pasoElArranque(RouteNames.setup.path), isFalse);
    expect(pasoElArranque('/setup'), isFalse);
  });

  test('home y tutorial sí', () {
    expect(pasoElArranque(RouteNames.home.path), isTrue);
    expect(pasoElArranque(RouteNames.tutorial.path), isTrue);
  });

  test('una ruta interna también cuenta', () {
    expect(pasoElArranque('/home/album/123'), isTrue);
    expect(pasoElArranque('/home/playlist/9'), isTrue);
  });
}
