// ─────────────────────────────────────────────────────────────
// caratula_playlist_test.dart — Prueba la prioridad de la portada de
// una playlist: la PROPIA (la foto que el usuario le puso) gana sobre
// la del like y la del lote de descarga.
//
// Por qué existe: el detalle resolvía primero la del like y después la
// del lote, así que una playlist descargada (o con el corazón) mostraba
// el arte del proveedor y "se comía" la foto elegida.
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:bitly/shared/utilidades/portada/base/caratula_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('bitly_caratula'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// Crea un archivo local real (las rutas muertas no cuentan).
  String archivo(String nombre) =>
      (File('${tmp.path}/$nombre')..writeAsBytesSync([1])).path;

  test('la foto propia gana sobre el like y el lote', () {
    final propia = archivo('propia.jpg');
    final ganadora = mejorCaratulaPlaylist(
      propia,
      'https://proveedor/like.jpg',
      'https://proveedor/lote.jpg',
    );

    expect(ganadora, propia);
  });

  test('sin propia se usa la del like', () {
    expect(
      mejorCaratulaPlaylist(
        null,
        'https://proveedor/like.jpg',
        'https://proveedor/lote.jpg',
      ),
      'https://proveedor/like.jpg',
    );
  });

  test('sin propia ni like se usa la del lote descargado', () {
    expect(
      mejorCaratulaPlaylist('', '', 'https://proveedor/lote.jpg'),
      'https://proveedor/lote.jpg',
    );
  });

  test('una propia MUERTA no tapa al like ni al lote', () {
    final muerta = '${tmp.path}/ya_no_esta.jpg';

    expect(
      mejorCaratulaPlaylist(
        muerta,
        'https://proveedor/like.jpg',
        'https://proveedor/lote.jpg',
      ),
      'https://proveedor/like.jpg',
    );
  });

  test('sin nada devuelve null (la tarjeta usa su marcador)', () {
    expect(mejorCaratulaPlaylist(null, null, ''), isNull);
  });
}
