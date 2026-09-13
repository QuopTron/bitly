// tutorial_overlay_ubicacion.dart — PART de tutorial_overlay.dart: decide
// DÓNDE va la tarjeta del tutorial (abajo, arriba o centrada).
//
// Está separado del widget a propósito: es una función pura, así que se puede
// verificar con tests (celu y PC) que la tarjeta nunca quede fuera de pantalla
// ni aplastada, sin montar el overlay.
//
// Se conecta con: tutorial_overlay_tooltip (lo usa para posicionarse).
// Parte del flujo: tutorial interactivo (geometría de la capa 2).
part of 'tutorial_overlay.dart';

/// Alto mínimo de banda libre para poner la tarjeta de un lado del objetivo.
/// Debajo de esto la tarjeta no se lee: se prefiere centrar. Es público para
/// que los tests verifiquen la misma regla que usa el overlay.
const double bandaMinimaTarjeta = 188;

/// Separación entre la tarjeta (y su flecha) y el widget explicado.
const double _hueco = 14;

/// Verde del halo del spotlight, para que la flecha combine con el agujero.
const Color _verdeTutorial = Color(0xFF1DB954);

/// Dónde se coloca la tarjeta respecto al widget explicado.
enum LadoTarjeta { abajo, arriba, centrada }

/// Geometría ya decidida para la tarjeta de un paso.
///
/// Se calcula aparte del widget (`ubicarTarjeta`) para poder verificar la
/// decisión con tests: la regla importante es que la tarjeta NUNCA quede
/// fuera de pantalla ni aplastada a cero.
class UbicacionTarjeta {
  /// Lado elegido.
  final LadoTarjeta lado;

  /// Borde izquierdo y ancho de la tarjeta.
  final double izquierda;
  final double ancho;

  /// Distancia desde arriba y desde abajo del área útil (px). En [LadoTarjeta]
  /// .centrada se usan para el área completa.
  final double arriba;
  final double abajo;

  /// Alto real disponible para la tarjeta en esa ubicación.
  final double banda;

  /// Corrimiento de la flecha para que apunte al centro del objetivo.
  final double punta;

  const UbicacionTarjeta({
    required this.lado,
    required this.izquierda,
    required this.ancho,
    required this.arriba,
    required this.abajo,
    required this.banda,
    required this.punta,
  });

  /// Si lleva flecha (solo cuando está pegada al objetivo).
  bool get conFlecha => lado != LadoTarjeta.centrada;

  /// Si la tarjeta va debajo del objetivo (flecha apuntando hacia arriba).
  bool get flechaArriba => lado == LadoTarjeta.abajo;
}

/// Decide dónde va la tarjeta: debajo del objetivo (lo normal), arriba (si
/// abajo no hay lugar) o centrada (el objetivo ocupa la pantalla, como el
/// feed, y no hay banda libre de ningún lado).
///
/// Pura a propósito: mismas entradas, misma salida, y se puede testear sin
/// montar el overlay.
UbicacionTarjeta ubicarTarjeta({
  required Rect? objetivo,
  required Size pantalla,
  required EdgeInsets inset,
  required double ancho,
}) {
  final utilArriba = inset.top + 12;
  final utilAbajo = inset.bottom + 12;
  final izquierda =
      objetivo == null
          ? (pantalla.width - ancho) / 2
          : (objetivo.center.dx - ancho / 2)
              .clamp(12.0, math.max(12.0, pantalla.width - ancho - 12))
              .toDouble();

  UbicacionTarjeta centrada() => UbicacionTarjeta(
    lado: LadoTarjeta.centrada,
    izquierda: izquierda,
    ancho: ancho,
    arriba: utilArriba,
    abajo: utilAbajo,
    banda: pantalla.height - utilArriba - utilAbajo,
    punta: 0,
  );

  // Sin objetivo montado (la función vive en otra vista): centrada.
  if (objetivo == null) return centrada();

  // Bandas libres reales, en píxeles, arriba y abajo del objetivo.
  final bandaAbajo = pantalla.height - utilAbajo - (objetivo.bottom + _hueco);
  final bandaArriba = (objetivo.top - _hueco) - utilArriba;

  // El objetivo se come la pantalla: centrada, sin flecha.
  if (bandaAbajo < bandaMinimaTarjeta && bandaArriba < bandaMinimaTarjeta) {
    return centrada();
  }

  final vaAbajo = bandaAbajo >= bandaArriba;
  return UbicacionTarjeta(
    lado: vaAbajo ? LadoTarjeta.abajo : LadoTarjeta.arriba,
    izquierda: izquierda,
    ancho: ancho,
    arriba: vaAbajo ? objetivo.bottom + _hueco : utilArriba,
    abajo: vaAbajo ? utilAbajo : pantalla.height - (objetivo.top - _hueco),
    banda: vaAbajo ? bandaAbajo : bandaArriba,
    // La flecha se corre para apuntar al centro del objetivo sin salirse.
    punta:
        (objetivo.center.dx - izquierda - 13)
            .clamp(16.0, math.max(16.0, ancho - 38))
            .toDouble(),
  );
}
