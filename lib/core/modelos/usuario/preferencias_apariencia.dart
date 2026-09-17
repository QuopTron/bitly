// preferencias_apariencia.dart — Preferencias de DISEÑO que el usuario
// puede ajustar en Ajustes → Apariencia: el borde del reproductor
// (navbar/miniplayer), la separación entre cards de las grillas (X e Y)
// y el redondeo de las cards.
//
// Los valores por defecto son EXACTAMENTE el diseño actual de la app:
// abrir Ajustes sin tocar nada deja todo como estaba.

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Grosor del borde del reproductor (navbar/miniplayer).
enum BordeMiniplayer {
  /// Sin borde: la barra queda pegada al fondo.
  sinBorde('sin_borde'),

  /// Borde suave: el que trae la app por defecto.
  suave('suave'),

  /// Borde marcado: se nota el contorno de la barra.
  marcado('marcado');

  final String clave;

  const BordeMiniplayer(this.clave);

  /// Convierte una clave guardada al valor correspondiente.
  static BordeMiniplayer desdeClave(String? clave) {
    for (final valor in BordeMiniplayer.values) {
      if (valor.clave == clave) return valor;
    }
    return BordeMiniplayer.suave;
  }
}

/// Preferencias de diseño del usuario.
class PreferenciasApariencia {
  /// Borde del reproductor (navbar/miniplayer).
  final BordeMiniplayer bordeMiniplayer;

  /// Separación horizontal entre cards de una grilla, como MULTIPLICADOR
  /// del diseño actual (0 = pegadas, 1 = el diseño de siempre).
  final double espacioX;

  /// Separación vertical entre cards de una grilla (mismo criterio).
  final double espacioY;

  /// Redondeo de las cards de grilla, en píxeles lógicos.
  final double radioCards;

  const PreferenciasApariencia({
    this.bordeMiniplayer = BordeMiniplayer.suave,
    this.espacioX = 1,
    this.espacioY = 1,
    this.radioCards = 14,
  });

  /// Diseño de fábrica: el que trae la app sin tocar nada.
  static const deFabrica = PreferenciasApariencia();

  /// Rango admitido del multiplicador de separación.
  static const minEspacio = 0.0;
  static const maxEspacio = 2.0;

  /// Rango admitido del redondeo de las cards.
  static const minRadio = 0.0;
  static const maxRadio = 28.0;

  /// Copia con los campos indicados cambiados (y ya acotados).
  PreferenciasApariencia copiarCon({
    BordeMiniplayer? bordeMiniplayer,
    double? espacioX,
    double? espacioY,
    double? radioCards,
  }) {
    return PreferenciasApariencia(
      bordeMiniplayer: bordeMiniplayer ?? this.bordeMiniplayer,
      espacioX: acotar(espacioX ?? this.espacioX, minEspacio, maxEspacio),
      espacioY: acotar(espacioY ?? this.espacioY, minEspacio, maxEspacio),
      radioCards: acotar(radioCards ?? this.radioCards, minRadio, maxRadio),
    );
  }

  /// ¿Están todos los valores en el diseño de fábrica?
  bool get esDeFabrica =>
      bordeMiniplayer == deFabrica.bordeMiniplayer &&
      (espacioX - deFabrica.espacioX).abs() < 0.001 &&
      (espacioY - deFabrica.espacioY).abs() < 0.001 &&
      (radioCards - deFabrica.radioCards).abs() < 0.001;

  /// Serializa a JSON para persistencia.
  Map<String, dynamic> aJson() => {
        'bordeMiniplayer': bordeMiniplayer.clave,
        'espacioX': espacioX,
        'espacioY': espacioY,
        'radioCards': radioCards,
      };

  /// Deserializa desde JSON (con acotado de rangos).
  factory PreferenciasApariencia.desdeJson(Map<String, dynamic> json) {
    return PreferenciasApariencia(
      bordeMiniplayer:
          BordeMiniplayer.desdeClave(json['bordeMiniplayer'] as String?),
      espacioX: acotar(
        (json['espacioX'] as num?)?.toDouble() ?? deFabrica.espacioX,
        minEspacio,
        maxEspacio,
      ),
      espacioY: acotar(
        (json['espacioY'] as num?)?.toDouble() ?? deFabrica.espacioY,
        minEspacio,
        maxEspacio,
      ),
      radioCards: acotar(
        (json['radioCards'] as num?)?.toDouble() ?? deFabrica.radioCards,
        minRadio,
        maxRadio,
      ),
    );
  }

  /// Serializa a string JSON para guardado en la base.
  String toJsonString() => jsonEncode(aJson());

  /// Deserializa desde string JSON; cualquier problema deja el diseño de
  /// fábrica (nunca rompe el arranque por una preferencia vieja).
  static PreferenciasApariencia desdeJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return deFabrica;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) {
        return PreferenciasApariencia.desdeJson(parsed);
      }
    } catch (e) {
      debugPrint('[Apariencia] preferencias ilegibles: $e');
    }
    return deFabrica;
  }
}

/// Acota un valor al rango pedido.
double acotar(double valor, double minimo, double maximo) {
  if (valor.isNaN) return minimo;
  if (valor < minimo) return minimo;
  if (valor > maximo) return maximo;
  return valor;
}
