// pool_qobuz_defecto_test.dart — Fija el push que dispara el POOL DE QOBUZ POR
// DEFECTO en el backend.
//
// Por qué existe: el backend arma el pool de Qobuz desde un origen de fábrica
// (sessionpool.QobuzPoolURLsPorDefecto → el /pool del Worker propio) cuando el
// usuario NO configuró ninguna URL. Ese trabajo se dispara con el push de
// ajustes de `qobuz-web`; si la app se lo saltea (porque no hay credenciales
// guardadas), el default nunca corre y "apuntado por defecto" queda en nada.
// Por eso `qobuz-web` marca `empujarSiempre: true`.
//
// Se conecta con: core/modelos/proveedores (registro + ConfigProveedor) y
// core/servicios/proveedores (ServicioCredencialesProveedor, que respeta el flag).
import 'package:flutter_test/flutter_test.dart';

import 'package:bitly/core/modelos/proveedores/base/config_proveedor.dart';

ConfigProveedor _porId(String id) =>
    ConfigProveedor.todos.firstWhere((p) => p.id == id);

void main() {
  test('qobuz-web se empuja aunque no haya credenciales', () {
    final qobuz = _porId('qobuz-web');
    expect(
      qobuz.empujarSiempre,
      isTrue,
      reason: 'sin este push, el backend nunca arma el pool por defecto',
    );
    expect(qobuz.claves, contains('qobuzPoolUrls'));
  });

  test('el default no empuja de más: las otras fuentes sin credenciales se saltan', () {
    for (final id in ['tidal-web', 'deezer']) {
      expect(_porId(id).empujarSiempre, isFalse, reason: '$id no tiene origen de fábrica');
    }
  });

  test('empujarSiempre arranca en false', () {
    const base = ConfigProveedor(id: 'x', nombreMostrado: 'X', claves: ['a']);
    expect(base.empujarSiempre, isFalse);
  });
}
