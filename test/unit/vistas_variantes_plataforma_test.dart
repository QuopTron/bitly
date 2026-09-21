// ─────────────────────────────────────────────────────────────
// vistas_variantes_plataforma_test.dart — Vigila la regla "cada
// vista tiene TRES diseños": celular, PC y TV, cada uno en su
// archivo, y el selector preguntando TV ANTES que PC (una tele
// ancha también entra en el layout de escritorio).
//
// Por qué existe: es fácil que una vista quede con dos diseños y
// reusar el de PC en la tele (o al revés), y eso no lo ve ningún
// test de widget. Acá se recorren las familias y se exige el
// archivo por variante, el orden del selector y que ninguna
// variante quede huérfana. Es el mismo patrón que
// reproductor_variantes_plataforma_test.dart.
// Parte del flujo: cualquier vista que se abra en celular, PC o TV.
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Una familia de vista: sus tres diseños y quién los elige.
class _Familia {
  final String nombre;

  /// Un archivo por plataforma.
  final String celular;
  final String pc;
  final String tv;

  /// El archivo que elige entre las tres (o entre PC y celular, si la TV la
  /// eligen las páginas de la familia).
  final String selector;

  /// Si el selector pregunta TV primero. En Detalle y Ajustes no aplica: ahí la
  /// TV se resuelve en otro archivo (las páginas y el navegador del menú).
  final bool tvPrimero;

  const _Familia({
    required this.nombre,
    required this.celular,
    required this.pc,
    required this.tv,
    required this.selector,
    this.tvPrimero = true,
  });
}

const _vistas = <_Familia>[
  _Familia(
    nombre: 'Home',
    celular: 'lib/features/home/movil/base/home_movil.dart',
    pc: 'lib/features/home/escritorio/home_escritorio.dart',
    tv: 'lib/features/home/tv/home_tv.dart',
    selector: 'lib/features/home/shell/pagina_home.dart',
  ),
  _Familia(
    nombre: 'Búsqueda',
    celular: 'lib/features/busqueda/vistas/busqueda_movil.dart',
    pc: 'lib/features/busqueda/vistas/busqueda_escritorio.dart',
    tv: 'lib/features/busqueda/vistas/busqueda_tv.dart',
    selector: 'lib/features/busqueda/pagina/base/pagina_busqueda.dart',
  ),
  _Familia(
    nombre: 'Inicio (feed)',
    celular: 'lib/features/feed/vistas/feed_movil.dart',
    pc: 'lib/features/feed/vistas/feed_escritorio.dart',
    tv: 'lib/features/feed/vistas/feed_tv.dart',
    selector: 'lib/features/feed/pagina/feed_pagina.dart',
  ),
  _Familia(
    nombre: 'Mi Espacio',
    celular: 'lib/features/mi_espacio/vistas/mi_espacio_movil.dart',
    pc: 'lib/features/mi_espacio/vistas/mi_espacio_escritorio.dart',
    tv: 'lib/features/mi_espacio/vistas/mi_espacio_tv.dart',
    selector:
        'lib/features/mi_espacio/pagina/base/pagina_mi_espacio_build.dart',
  ),
  _Familia(
    nombre: 'Splash',
    celular: 'lib/features/splash/vistas/splash_movil.dart',
    pc: 'lib/features/splash/vistas/splash_escritorio.dart',
    tv: 'lib/features/splash/vistas/splash_tv.dart',
    selector: 'lib/features/splash/pagina/pagina_splash.dart',
  ),
  _Familia(
    nombre: 'Setup',
    celular: 'lib/features/setup/vistas/setup_movil.dart',
    pc: 'lib/features/setup/vistas/setup_escritorio.dart',
    tv: 'lib/features/setup/vistas/setup_tv.dart',
    selector: 'lib/features/setup/pagina/pagina_setup.dart',
  ),
  _Familia(
    nombre: 'Tutorial',
    celular: 'lib/features/tutorial/vistas/tutorial_movil.dart',
    pc: 'lib/features/tutorial/vistas/tutorial_escritorio.dart',
    tv: 'lib/features/tutorial/vistas/tutorial_tv.dart',
    selector: 'lib/features/tutorial/pagina/tutorial_pagina.dart',
  ),
  _Familia(
    nombre: 'Detalle (álbum/artista/playlist)',
    celular: 'lib/features/detalle/comun/vistas/detalle_movil.dart',
    pc: 'lib/features/detalle/comun/vistas/detalle_escritorio.dart',
    tv: 'lib/features/detalle/comun/vistas/detalle_tv.dart',
    selector: 'lib/features/detalle/comun/cabecera/cabecera_detalle.dart',
    tvPrimero: false,
  ),
  _Familia(
    nombre: 'Reproductor',
    celular: 'lib/features/reproductor/vistas/reproductor_movil.dart',
    pc: 'lib/features/reproductor/vistas/reproductor_escritorio.dart',
    tv: 'lib/features/reproductor/vistas/reproductor_tv.dart',
    selector: 'lib/features/reproductor/vistas/vista_reproductor.dart',
  ),
  _Familia(
    nombre: 'Ajustes (navegador)',
    celular:
        'lib/features/ajustes/sheet/nav/burbujas/settings_sheet_nav_burbujas.dart',
    pc: 'lib/features/ajustes/sheet/nav/riel/settings_sheet_nav_riel.dart',
    tv: 'lib/features/ajustes/sheet/nav/riel/settings_sheet_nav_riel_tv.dart',
    selector: 'lib/features/ajustes/sheet/nav/base/settings_sheet_nav.dart',
    tvPrimero: false,
  ),
];

String _leer(String ruta) =>
    File(ruta).readAsStringSync().replaceAll('\r\n', '\n');

/// Saca los comentarios: mencionar una plataforma en la cabecera no cuenta.
String _soloCodigo(String fuente) => fuente
    .split('\n')
    .where((linea) => !linea.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('cada familia de vista tiene sus TRES diseños en archivos aparte', () {
    for (final v in _vistas) {
      for (final entrada
          in {'celular': v.celular, 'PC': v.pc, 'TV': v.tv}.entries) {
        expect(
          File(entrada.value).existsSync(),
          isTrue,
          reason:
              '${v.nombre}: falta el diseño de ${entrada.key} '
              '(${entrada.value})',
        );
      }
      // Las tres variantes no pueden ser el mismo archivo.
      expect(
        {v.celular, v.pc, v.tv},
        hasLength(3),
        reason:
            '${v.nombre}: las tres variantes tienen que ser archivos '
            'distintos',
      );
    }
  });

  test('el selector elige entre PC y celular', () {
    for (final v in _vistas) {
      expect(
        _soloCodigo(_leer(v.selector)),
        contains('usarLayoutEscritorio'),
        reason: '${v.nombre}: ${v.selector} no elige entre PC y celular',
      );
    }
  });

  test('el selector pregunta TV antes que PC', () {
    for (final v in _vistas.where((v) => v.tvPrimero)) {
      final codigo = _soloCodigo(_leer(v.selector));
      final tv = codigo.indexOf('usarLayoutTv');
      final pc = codigo.indexOf('usarLayoutEscritorio');
      expect(tv, greaterThan(-1), reason: '${v.nombre}: no mira TV');
      expect(pc, greaterThan(-1), reason: '${v.nombre}: no mira PC');
      expect(
        tv,
        lessThan(pc),
        reason:
            '${v.nombre}: una tele ancha también entra en el layout de '
            'escritorio, así que TV se pregunta PRIMERO o la tele termina '
            'usando el diseño de PC',
      );
    }
  });

  test('ningún diseño de plataforma quedó huérfano', () {
    final archivos =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();
    final contenidos = <String, String>{};
    for (final f in archivos) {
      contenidos[f.path] = _leer(f.path);
    }

    for (final v in _vistas) {
      for (final ruta in [v.celular, v.pc, v.tv]) {
        final archivo = ruta.split('/').last;
        final quienLoUsa =
            contenidos.entries
                .where((e) => e.key != ruta && e.value.contains(archivo))
                .length;
        expect(
          quienLoUsa,
          greaterThan(0),
          reason:
              '${v.nombre}: $archivo no lo monta nadie (¿quedó sin '
              'conectar?)',
        );
      }
    }
  });
}
