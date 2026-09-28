// ─────────────────────────────────────────────────────────────
// lector_qr_test.dart — Prueba el MOTOR de lectura de QR sin cámara.
//
// Por qué existe: al cambiar ML Kit (`mobile_scanner`) por un decodificador en
// Dart había que poder comprobar que lee de verdad, y que lo hace con los
// fotogramas EXACTOS que devuelve una cámara: capa Y con relleno de fila
// (`bytesPorFila > ancho`, lo normal en Android) y en cualquier rotación (el
// sensor entrega la imagen acostada).
//
// El QR de prueba lo genera el propio zxing2 (encoder), se dibuja a mano en un
// buffer de luminancia y se lo pasa al lector: es un ida y vuelta, pero por dos
// caminos distintos del paquete (encoder vs detector), que es justo lo que hay
// que cubrir.
//
// Se conecta con: lector_qr.dart.
// Parte del flujo: Ajustes → Conexión → vincular con QR.
// ─────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bitly/features/ajustes/sheet/conexion/qr/base/lector_qr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zxing2/qrcode.dart';

/// Dibuja [texto] como QR en un buffer de luminancia (capa Y), con [escala]
/// píxeles por módulo y [margen] módulos de aire alrededor.
///
/// [relleno] agrega bytes al final de cada fila, como hacen las cámaras: es el
/// caso que rompe a un lector que asume filas contiguas.
({Uint8List bytes, int ancho, int alto, int bytesPorFila}) dibujarQr(
  String texto, {
  int escala = 4,
  int margen = 4,
  int relleno = 0,
  int rotacion = 0,
}) {
  final qr = Encoder.encode(texto, ErrorCorrectionLevel.m);
  final m = qr.matrix!;
  final modulos = m.width + margen * 2;
  final lado = modulos * escala;
  final bytesPorFila = lado + relleno;

  // El fondo (aire) es blanco y los módulos negros: un QR invertido depende del
  // lector, así que se dibuja como sale de una impresora.
  final bytes = Uint8List(bytesPorFila * lado)..fillRange(0, bytesPorFila * lado, 0xFF);
  for (var y = 0; y < m.height; y++) {
    for (var x = 0; x < m.width; x++) {
      if (m.get(x, y) != 1) continue;
      for (var dy = 0; dy < escala; dy++) {
        for (var dx = 0; dx < escala; dx++) {
          final px = (x + margen) * escala + dx;
          final py = (y + margen) * escala + dy;
          // Rotación en el DESTINO: es lo que hace el sensor con la imagen.
          final (rx, ry) = switch (rotacion % 360) {
            90 => (lado - 1 - py, px),
            180 => (lado - 1 - px, lado - 1 - py),
            270 => (py, lado - 1 - px),
            _ => (px, py),
          };
          bytes[ry * bytesPorFila + rx] = 0x00;
        }
      }
    }
  }
  return (bytes: bytes, ancho: lado, alto: lado, bytesPorFila: bytesPorFila);
}

void main() {
  final lector = LectorQr();

  test('lee un QR en el fotograma tal como sale de la cámara', () {
    const texto = 'bitly://vincular?code=7F3K9Q';
    final f = dibujarQr(texto);
    expect(
      lector.leer(
        bytes: f.bytes,
        ancho: f.ancho,
        alto: f.alto,
        bytesPorFila: f.bytesPorFila,
      ),
      texto,
    );
  });

  test('lee aunque las filas vengan con relleno (stride de la cámara)', () {
    // Android suele devolver filas alineadas (más anchas que el ancho útil).
    // Si el lector las tratara como contiguas, la imagen saldría "torcida" y no
    // decodificaría NUNCA.
    const texto = 'bitly://vincular?code=ABC123';
    final f = dibujarQr(texto, relleno: 37, escala: 6);
    expect(
      lector.leer(
        bytes: f.bytes,
        ancho: f.ancho,
        alto: f.alto,
        bytesPorFila: f.bytesPorFila,
      ),
      texto,
    );
  });

  test('lee el QR en las cuatro rotaciones (sensor acostado)', () {
    // No hace falta rotar el fotograma: ZXing ubica los tres cuadrados de las
    // esquinas. Esta prueba es el seguro de esa decisión: si alguien la cambia,
    // acá se ve.
    const texto = 'bitly://vincular?code=ROTADO';
    for (final grados in [0, 90, 180, 270]) {
      final f = dibujarQr(texto, rotacion: grados);
      expect(
        lector.leer(
          bytes: f.bytes,
          ancho: f.ancho,
          alto: f.alto,
          bytesPorFila: f.bytesPorFila,
        ),
        texto,
        reason: 'no leyó el QR rotado $grados°',
      );
    }
  });

  test('un QR con otra carga también se lee (no está cableado el texto)', () {
    final texto = 'https://bitly.app/?v=${List.generate(40, (i) => i).join()}';
    final f = dibujarQr(texto, escala: 3);
    expect(
      lector.leer(
        bytes: f.bytes,
        ancho: f.ancho,
        alto: f.alto,
        bytesPorFila: f.bytesPorFila,
      ),
      texto,
    );
  });

  test('sin QR devuelve null y no explota', () {
    // Ruido: lo que llega la mayoría de los fotogramas mientras el usuario
    // apunta. Tiene que devolver null, no tirar excepción.
    final azar = math.Random(7);
    const lado = 120;
    final bytes = Uint8List(lado * lado);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = azar.nextInt(256);
    }
    expect(
      lector.leer(bytes: bytes, ancho: lado, alto: lado, bytesPorFila: lado),
      isNull,
    );
  });

  test('un fotograma en blanco (sin QR) devuelve null', () {
    const lado = 80;
    final bytes = Uint8List(lado * lado)..fillRange(0, lado * lado, 0xFF);
    expect(
      lector.leer(bytes: bytes, ancho: lado, alto: lado, bytesPorFila: lado),
      isNull,
    );
  });

  test('medidas inválidas no rompen el lector', () {
    final bytes = Uint8List(64);
    // Ancho cero y fila más corta que el ancho: se descartan antes de tocar
    // ZXing (un plugin de cámara puede informar cualquier cosa).
    expect(
      lector.leer(bytes: bytes, ancho: 0, alto: 8, bytesPorFila: 0),
      isNull,
    );
    expect(
      lector.leer(bytes: bytes, ancho: 16, alto: 8, bytesPorFila: 4),
      isNull,
    );
  });

  test('el mismo lector sirve para varios fotogramas seguidos', () {
    // La pantalla reusa UNA instancia entre frames (crear una por fotograma
    // tira memoria en cada cuadro). Acá se comprueba que no queda "sucia".
    const primera = 'bitly://vincular?code=UNO';
    const segunda = 'bitly://vincular?code=DOS';
    for (final texto in [primera, segunda, primera]) {
      final f = dibujarQr(texto, escala: 3);
      expect(
        lector.leer(
          bytes: f.bytes,
          ancho: f.ancho,
          alto: f.alto,
          bytesPorFila: f.bytesPorFila,
        ),
        texto,
      );
    }
  });
}
