// ─────────────────────────────────────────────────────────────
// lector_qr.dart — El MOTOR de lectura de QR: convierte el cuadro de la cámara
// (la capa Y del formato YUV420, que ya ES la luminancia) en el texto del QR.
//
// Por qué existe: la cámara y el decodificador son dos cosas distintas y sólo
// la segunda se puede probar sin teléfono. Este archivo no sabe nada de
// widgets ni de `camera`: entra un buffer de bytes y sale un texto (o null).
// Eso lo hace comprobable con un QR generado a mano en un test, a cualquier
// rotación y con o sin relleno de fila (las cámaras suelen devolver filas más
// anchas que el ancho útil).
//
// Por qué zxing2 y no ML Kit: ML Kit empaquetado costaba ~3 MB por APK
// (libbarhopper_v3.so + modelos .tflite) para UNA pantalla de vinculación.
// zxing2 es Dart puro: no agrega ninguna .so.
//
// Se conecta con: settings_conexion_qr_camara.dart (lo alimenta con los
// fotogramas) y con `zxing2` (el decodificador).
// Parte del flujo: Ajustes → Conexión → vincular con QR.
// ─────────────────────────────────────────────────────────────

import 'dart:typed_data';

import 'package:zxing2/qrcode.dart';

/// La capa Y (luminancia) de un fotograma YUV420 como fuente para ZXing.
///
/// ZXing pide filas de luminancia; la capa Y de YUV420 ya viene así — un byte
/// por píxel, en escala de grises —, así que no hay que convertir nada a RGB:
/// se lee el buffer tal cual. La única trampa es [bytesPorFila]: las cámaras
/// casi siempre devuelven filas más anchas que [ancho] (padding de alineación),
/// y leerlas como si fueran contiguas "tuerce" la imagen y ningún QR decodifica.
class FuenteLuminanciaY extends LuminanceSource {
  final Uint8List bytes;

  /// Cuántos bytes ocupa cada fila REAL en [bytes] (>= [ancho]).
  final int bytesPorFila;

  FuenteLuminanciaY({
    required this.bytes,
    required int ancho,
    required int alto,
    required this.bytesPorFila,
  }) : super(ancho, alto);

  @override
  Int8List getRow(int y, Int8List? row) {
    final destino = row ?? Int8List(width);
    final base = y * bytesPorFila;
    // Copia a mano y no `setRange`: con `bytesPorFila > width` el origen no es
    // contiguo. Asignar a Int8List guarda el byte tal cual (ZXing después hace
    // `& 0xFF`), así que el signo no molesta.
    for (var x = 0; x < width; x++) {
      destino[x] = bytes[base + x];
    }
    return destino;
  }

  @override
  Int8List getMatrix() {
    // Sin padding es una vista del mismo buffer (cero copias); con padding hay
    // que compactar fila por fila. ZXing sólo lo llama si no pidió filas antes.
    if (bytesPorFila == width) {
      return Int8List.sublistView(bytes, 0, width * height);
    }
    final plano = Int8List(width * height);
    for (var y = 0; y < height; y++) {
      final base = y * bytesPorFila;
      for (var x = 0; x < width; x++) {
        plano[y * width + x] = bytes[base + x];
      }
    }
    return plano;
  }
}

/// Lee un QR de un fotograma de cámara. Devuelve `null` si no hay ninguno.
///
/// Se reusa el MISMO lector entre fotogramas (armar uno por fotograma tira
/// memoria en cada frame, que es justo lo que no se quiere en un teléfono
/// lento). No hace falta rotar la imagen: el detector de QR de ZXing ubica los
/// tres cuadrados de las esquinas y deduce la orientación solo, así que un
/// fotograma acostado se lee igual (está cubierto en los tests).
class LectorQr {
  final QRCodeReader _lector = QRCodeReader();

  /// `tryHarder`: se gasta más tiempo por fotograma a cambio de encontrar QRs
  /// difíciles (poco contraste, un poco torcidos). Acá conviene: el fotograma
  /// que ya no sirve se descarta igual y el usuario sólo necesita que enganche.
  final DecodeHints _pistas = DecodeHints()..put(DecodeHintType.tryHarder);

  /// [ancho]/[alto] son los de la capa Y (no los de la pantalla).
  String? leer({
    required Uint8List bytes,
    required int ancho,
    required int alto,
    required int bytesPorFila,
  }) {
    if (ancho <= 0 || alto <= 0 || bytesPorFila < ancho) return null;
    try {
      final fuente = FuenteLuminanciaY(
        bytes: bytes,
        ancho: ancho,
        alto: alto,
        bytesPorFila: bytesPorFila,
      );
      // HybridBinarizer y no GlobalHistogramBinarizer: se banca la luz
      // despareja (una lámpara, el reflejo en la pantalla del otro aparato).
      final bitmap = BinaryBitmap(HybridBinarizer(fuente));
      final resultado = _lector.decode(bitmap, hints: _pistas);
      final texto = resultado.text;
      return texto.isEmpty ? null : texto;
    } on NotFoundException {
      // Lo normal: este fotograma no tenía un QR. No es un error.
      return null;
    } catch (_) {
      // Un fotograma ilegible no puede tumbar la pantalla de vinculación.
      return null;
    }
  }
}
