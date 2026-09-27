// ─────────────────────────────────────────────────────────────
// especificaciones_plataforma_test.dart — Vigila que cada aparato
// tenga SU versión de las medidas, y que los componentes la usen.
//
// Tres reglas:
//   1. hay una tabla por aparato (celular, PC, TV) y no son iguales;
//   2. la TV agranda todo (factorEscala > 1) y Responsive lo aplica;
//   3. TODO componente de shared/widgets con medidas fijas tiene que
//      leer las especificaciones (o Responsive), salvo los de la lista
//      de excepciones —que son decoración o piezas sólo de TV—;
//   4. lo mismo para TODO widget de features/** (vistas y piezas): antes
//      la regla sólo cubría shared, así que un ícono o un texto de una
//      vista quedaba con el número de celular también en la tele.
//
// Por qué existe: sin esto, un botón o una fila nueva vuelve a quedar
// con los números de celular en la tele, que es justo lo que se quiere
// evitar. Parte del flujo: presentación (medidas por plataforma).
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _tablas = {
  'celular': 'lib/shared/tema/especificaciones/especificaciones_celular.dart',
  'PC': 'lib/shared/tema/especificaciones/especificaciones_pc.dart',
  'TV': 'lib/shared/tema/especificaciones/especificaciones_tv.dart',
};

const _modelo =
    'lib/shared/tema/especificaciones/especificaciones_plataforma.dart';

/// Archivos con medidas que NO necesitan leer el aparato, y por qué.
const _excepciones = <String, String>{
  'lib/shared/widgets/tarjetas/grilla/visual/tarjeta_grilla_visual.dart':
      'sólo el grosor del borde (0.6): no se ve distinto por aparato',
  'lib/shared/widgets/tarjetas/grilla/visual/tarjeta_grilla_placeholder.dart':
      'sólo el grosor del borde del placeholder',
  'lib/shared/widgets/paneles/panel_tv.dart': 'ya es la pieza exclusiva de TV',
  'lib/shared/widgets/tv/puntero_tv_cursor.dart':
      'ya es la pieza exclusiva de TV',
  'lib/shared/widgets/fondos/particulas/fondo_particulas_particula.dart':
      'decoración: sólo el tamaño de una partícula',
  'lib/shared/widgets/base/overlay/visual/overlay_compartido_fondo.dart':
      'decoración: sólo el radio del fondo',
  'lib/shared/widgets/texto/mini_karaoke_letra.dart':
      'sólo alto de línea (1.25), que no es una medida de pantalla',
  // Piezas de hojas modales: sus números son separaciones (2, 3, 4, 6, 8) y
  // radios chicos (6, 12, 14) que se ven igual en cualquier aparato. El alto
  // y el ancho de la hoja los decide el contenedor, que sí mira el aparato.
  'lib/shared/widgets/modales/descarga/hoja_opciones_descarga_extra.dart':
      'separaciones chicas',
  'lib/shared/widgets/modales/descarga/hoja_opciones_descarga_opcion.dart':
      'separaciones y radio chicos',
  'lib/shared/widgets/modales/descarga/hoja_opciones_descarga_widgets.dart':
      'separaciones chicas',
  'lib/shared/widgets/modales/playlist/base/hoja_playlist_cabecera.dart':
      'tirador de la hoja (40x4) y radios de las tapas',
  'lib/shared/widgets/modales/playlist/lista/hoja_playlist_canciones.dart':
      'separaciones chicas',
  'lib/shared/widgets/modales/playlist/lista/hoja_playlist_lista.dart':
      'separaciones chicas',
  'lib/shared/widgets/modales/playlist/portada/hoja_playlist_portada.dart':
      'radio de la portada y el borde de la tapa',
  'lib/shared/widgets/modales/playlist/lista/hoja_playlist_vacio.dart':
      'separaciones chicas',
  'lib/shared/widgets/tarjetas/grilla/base/tarjeta_grilla_info.dart':
      'separaciones de 2/4 y radio 6 entre textos',
};

/// Igual que [_excepciones], para los widgets de features/**.
const _excepcionesFeatures = <String, String>{
  'lib/features/home/tv/home_tv_piezas.dart':
      'ya es la pieza exclusiva de la tele',
  'lib/features/reproductor/vistas/reproductor_tv.dart':
      'ya es la variante exclusiva de la tele',
  'lib/features/mi_espacio/vistas/mi_espacio_tv.dart':
      'ya es la variante exclusiva de la tele',
  'lib/features/tutorial/vistas/tutorial_tv.dart':
      'ya es la variante exclusiva de la tele',
  'lib/features/setup/widgets/slides/gracias/slide_gracias_widgets.dart':
      'sólo el grosor de un borde (1.5): no se ve distinto por aparato',
  'lib/features/ajustes/update/base/release_notas_vista.dart':
      'sólo alto de línea (1.35) dentro de un TextStyle: no es una medida de '
      'pantalla. El tamaño del texto y el puntito de cada viñeta llegan por '
      '`tamano`, que sale de Responsive en quien la monta',
};

String _leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

String _soloCodigo(String fuente) =>
    fuente.split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');

/// Un número de medida escrito a mano (no una constante ni una variable).
///
/// El `(?<![.\w])` evita los falsos positivos de las ternas
/// (`haciaArriba ? size.height : 0.0`), donde `height : 0.0` no es una
/// medida de ningún widget.
final _medidaFija = RegExp(
  r'(?<![.\w])(height|width|size|fontSize|radius|padding|margin) *: *[0-9]'
  r'|(?<![.\w])Radius\.circular\([0-9]',
);

/// ¿El archivo USA las medidas del aparato? (Importarlas no alcanza).
///
/// Vale de tres formas: construye un `Responsive`, pide las especificaciones,
/// o RECIBE un `Responsive` por parámetro y saca medidas de él (`r.val(...)`,
/// `r.spacingM`, …) — que es como se escalan las partes del miniplayer.
bool _usaElAparato(String fuente) =>
    RegExp(r'Responsive\(').hasMatch(fuente) ||
    fuente.contains('EspecificacionesPlataforma.de(') ||
    (RegExp(r'Responsive\s+\w').hasMatch(fuente) &&
        RegExp(r'\br\.').hasMatch(fuente));

/// Si el archivo es un `part`, la ruta de su librería (puede ser '../x.dart').
/// Una parte no puede importar: hereda los imports de la librería y, casi
/// siempre, recibe las medidas del widget que la usa. Por eso vale que la
/// librería sea consciente del aparato.
String? _libreriaDe(String ruta, String fuente) {
  final m = RegExp(r"part of '([^']+)'").firstMatch(fuente);
  if (m == null) return null;
  final destino = m.group(1)!;
  if (destino.startsWith('package:') || destino.startsWith('dart:')) {
    return null;
  }
  final dir =
      ruta.contains('/') ? ruta.substring(0, ruta.lastIndexOf('/')) : '';
  final partes = <String>[];
  for (final s in '$dir/$destino'.split('/')) {
    if (s.isEmpty || s == '.') continue;
    if (s == '..') {
      if (partes.isNotEmpty) partes.removeLast();
      continue;
    }
    partes.add(s);
  }
  return partes.join('/');
}

void main() {
  test('hay una tabla de medidas por aparato', () {
    for (final e in _tablas.entries) {
      expect(
        File(e.value).existsSync(),
        isTrue,
        reason: 'falta la tabla de ${e.key} (${e.value})',
      );
    }
    expect(File(_modelo).existsSync(), isTrue);
  });

  test('la TV agranda todo y PC/celular no escalan de más', () {
    final celular = _leer(_tablas['celular']!);
    final pc = _leer(_tablas['PC']!);
    final tv = _leer(_tablas['TV']!);

    expect(tv, contains('factorEscala: 1.45'));
    expect(celular, isNot(contains('factorEscala:')));
    expect(pc, isNot(contains('factorEscala:')));

    // Los números de la TV y de la PC tienen que ser DISTINTOS de los del
    // celular: si coincidieran, el aparato no tendría su propia versión.
    for (final token in [
      'altoBoton',
      'altoBotonIcono',
      'altoTile',
      'altoFila',
      'iconoTile',
      'radioTarjeta',
      'radioHoja',
      'textoBoton',
      'textoEtiqueta',
    ]) {
      expect(
        _valor(tv, token),
        greaterThan(_valor(celular, token)),
        reason: 'en la TV $token tiene que ser más grande que en celular',
      );
      expect(
        _valor(pc, token),
        isNot(_valor(celular, token)),
        reason: 'PC necesita su propio $token (hoy igual al de celular)',
      );
    }
    expect(pc, contains('focoVisible: false'));
    expect(celular, contains('focoVisible: false'));
    expect(tv, contains('focoVisible: true'));
  });

  test('Responsive escala por aparato, no sólo por ancho', () {
    final codigo = _soloCodigo(
      _leer('lib/shared/utilidades/plataforma/responsive.dart'),
    );
    expect(codigo, contains('factorEscala'));
    expect(codigo, contains('EspecificacionesPlataforma.de(context)'));
    expect(
      codigo,
      contains('min * factor'),
      reason:
          'los topes también tienen que escalar, si no la TV queda '
          'recortada al máximo de celular',
    );
  });

  test('el selector de especificaciones pregunta TV antes que PC', () {
    final codigo = _soloCodigo(_leer(_modelo));
    final tv = codigo.indexOf('usarLayoutTv');
    final pc = codigo.indexOf('usarLayoutEscritorio');
    expect(tv, greaterThan(-1));
    expect(pc, greaterThan(-1));
    expect(
      tv,
      lessThan(pc),
      reason: 'una tele ancha también entra en el layout de escritorio',
    );
  });

  test('todo componente de shared con medidas fijas lee el aparato', () {
    final infractores = _infractores('lib/shared/widgets', _excepciones);
    expect(
      infractores,
      isEmpty,
      reason:
          'estos componentes tienen medidas fijas y no miran el aparato, así '
          'que en la TV quedan con los números de celular. Cablealos a '
          'EspecificacionesPlataforma/Responsive, o sumalos a _excepciones '
          'explicando por qué no hace falta:\n${infractores.join('\n')}',
    );
  });

  test('todo widget de features con medidas fijas lee el aparato', () {
    final infractores = _infractores('lib/features', _excepcionesFeatures);
    expect(
      infractores,
      isEmpty,
      reason:
          'estos widgets de las vistas tienen medidas fijas y no miran el '
          'aparato, así que en la TV quedan con los números de celular. '
          'Cablealos a EspecificacionesPlataforma (radios, íconos, filas) o a '
          'Responsive (textos y separaciones), o sumalos a '
          '_excepcionesFeatures explicando por qué no hace falta:\n'
          '${infractores.join('\n')}',
    );
  });
}

/// Archivos de [raiz] con medidas fijas que no miran el aparato.
List<String> _infractores(String raiz, Map<String, String> excepciones) {
  final infractores = <String>[];
  for (final f in Directory(raiz).listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    final ruta = f.path.replaceAll(r'\', '/');
    if (excepciones.containsKey(ruta)) continue;
    final codigo = _leer(ruta);
    if (!_medidaFija.hasMatch(codigo)) continue;
    if (_usaElAparato(codigo)) continue;

    // Si es una parte, alcanza con que su librería mire el aparato.
    final libreria = _libreriaDe(ruta, codigo);
    if (libreria != null &&
        File(libreria).existsSync() &&
        _usaElAparato(_leer(libreria))) {
      continue;
    }
    infractores.add(ruta);
  }
  return infractores;
}

/// Lee el valor numérico de un token de una tabla de especificaciones.
double _valor(String tabla, String token) {
  final m = RegExp('$token: ([0-9.]+)').firstMatch(tabla);
  expect(m, isNotNull, reason: 'la tabla no define $token');
  return double.parse(m!.group(1)!);
}
