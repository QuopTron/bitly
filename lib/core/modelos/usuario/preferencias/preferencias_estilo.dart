// preferencias_estilo.dart — INTENSIDAD del "estilo con cover": cuánto del
// color de la carátula entra en cada parte de la app, de 0 (el diseño
// monocromático de fábrica) a 1 (todo con el color del cover).
//
// Antes esto eran 5 booleanos más un enum de modo (Clásico/Spotify): para
// pasar de uno al otro había que tocar 6 controles y no se podía estar "a
// medias". Ahora cada componente guarda un número, así que el color del
// cover entra de a poco y el usuario ve el efecto mientras desliza.
//
// Se conecta con: estilo_helper (leer/cambiar desde cualquier vista) y
// preferencias_estilo_json (guardar y leer, con la migración).
// Parte del flujo: Ajustes → Apariencia (estilo) y el pintado de la app.

import 'preferencias_apariencia.dart' show acotar;

/// Partes de la app que pueden tomar el color de la carátula.
enum ComponenteEstilo {
  /// Cards de canción (la fila de cada track).
  cardsCancion,

  /// Cards de grilla: álbumes, playlists y artistas.
  cardsGrilla,

  /// Fondo principal (inicio y cabeceras de detalle).
  fondoPrincipal,

  /// Fondo del reproductor a pantalla completa.
  fondoReproductor,

  /// Fondos de los modales (Ajustes, cola, letras).
  fondosModals,
}

/// Intensidad del estilo con cover, componente por componente.
class PreferenciasEstilo {
  final double cardsCancion;
  final double cardsGrilla;
  final double fondoPrincipal;
  final double fondoReproductor;
  final double fondosModals;

  const PreferenciasEstilo({
    this.cardsCancion = 0,
    this.cardsGrilla = 0,
    this.fondoPrincipal = 0,
    this.fondoReproductor = 0,
    this.fondosModals = 0,
  });

  /// Diseño de fábrica: monocromático, sin color de cover en ningún lado.
  static const normal = PreferenciasEstilo();

  /// Todo con el color del cover (el "Spotify" de antes, al máximo).
  static const completo = PreferenciasEstilo(
    cardsCancion: 1,
    cardsGrilla: 1,
    fondoPrincipal: 1,
    fondoReproductor: 1,
    fondosModals: 1,
  );

  /// Intensidad de un componente.
  double nivelDe(ComponenteEstilo componente) {
    switch (componente) {
      case ComponenteEstilo.cardsCancion:
        return cardsCancion;
      case ComponenteEstilo.cardsGrilla:
        return cardsGrilla;
      case ComponenteEstilo.fondoPrincipal:
        return fondoPrincipal;
      case ComponenteEstilo.fondoReproductor:
        return fondoReproductor;
      case ComponenteEstilo.fondosModals:
        return fondosModals;
    }
  }

  /// Copia con la intensidad de UN componente cambiada (ya acotada a 0..1).
  PreferenciasEstilo conNivel(ComponenteEstilo componente, double nivel) {
    final v = acotar(nivel, 0, 1);
    switch (componente) {
      case ComponenteEstilo.cardsCancion:
        return copiarCon(cardsCancion: v);
      case ComponenteEstilo.cardsGrilla:
        return copiarCon(cardsGrilla: v);
      case ComponenteEstilo.fondoPrincipal:
        return copiarCon(fondoPrincipal: v);
      case ComponenteEstilo.fondoReproductor:
        return copiarCon(fondoReproductor: v);
      case ComponenteEstilo.fondosModals:
        return copiarCon(fondosModals: v);
    }
  }

  /// Copia con los campos indicados cambiados (y ya acotados).
  PreferenciasEstilo copiarCon({
    double? cardsCancion,
    double? cardsGrilla,
    double? fondoPrincipal,
    double? fondoReproductor,
    double? fondosModals,
  }) {
    return PreferenciasEstilo(
      cardsCancion: acotar(cardsCancion ?? this.cardsCancion, 0, 1),
      cardsGrilla: acotar(cardsGrilla ?? this.cardsGrilla, 0, 1),
      fondoPrincipal: acotar(fondoPrincipal ?? this.fondoPrincipal, 0, 1),
      fondoReproductor: acotar(fondoReproductor ?? this.fondoReproductor, 0, 1),
      fondosModals: acotar(fondosModals ?? this.fondosModals, 0, 1),
    );
  }

  /// Todas las intensidades, en el orden de [ComponenteEstilo].
  List<double> get niveles => [
    cardsCancion,
    cardsGrilla,
    fondoPrincipal,
    fondoReproductor,
    fondosModals,
  ];

  /// Sin color de cover en ningún lado.
  bool get esNormal => niveles.every((n) => n == 0);

  /// ¿Todos los componentes están al mismo nivel? Si sí, el slider general
  /// puede mostrar ese valor; si no, el usuario personalizó.
  bool get esUniforme {
    final primero = niveles.first;
    return niveles.every((n) => (n - primero).abs() < 0.001);
  }

  /// Valor del slider GENERAL: el común si están todos iguales, y si no el
  /// promedio (el usuario ve "Personalizado" al lado).
  double get general {
    if (esUniforme) return niveles.first;
    return niveles.reduce((a, b) => a + b) / niveles.length;
  }
}
