// preferencias_apariencia.dart — Preferencias de DISEÑO que el usuario
// puede ajustar en Ajustes → Apariencia: el redondeo de las dos esquinas de
// ARRIBA del navbar y del miniplayer (con el trazo del contorno que comparten),
// la separación de las grillas y las cards (que mueve tanto el hueco entre
// cards como el margen contra los bordes) y el redondeo de las cards.
//
// La separación va POR COMPONENTE (cards de canción y cards de grilla) y por
// eje (X horizontal, Y vertical): el control general mueve los cuatro a la
// vez y en "Avanzado" se afinan por separado.
//
// Los valores por defecto son EXACTAMENTE el diseño actual de la app:
// abrir Ajustes sin tocar nada deja todo como estaba.

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Trazo del contorno del navbar y del miniplayer.
enum TrazoBarra {
  /// Sin contorno: la barra queda pegada al fondo.
  sinTrazo('sin_trazo'),

  /// Contorno suave: el que trae la app por defecto.
  suave('suave'),

  /// Contorno marcado: se nota el borde de la barra.
  marcado('marcado');

  final String clave;

  const TrazoBarra(this.clave);

  /// Convierte una clave guardada al valor correspondiente. Acepta la clave
  /// vieja 'sin_borde' para que las preferencias ya guardadas no se pierdan.
  static TrazoBarra desdeClave(String? clave) {
    if (clave == 'sin_borde') return TrazoBarra.sinTrazo;
    for (final valor in TrazoBarra.values) {
      if (valor.clave == clave) return valor;
    }
    return TrazoBarra.suave;
  }
}

/// Preferencias de diseño del usuario.
class PreferenciasApariencia {
  /// Trazo del contorno (navbar y miniplayer comparten el grosor elegido).
  final TrazoBarra trazoBarra;

  /// Redondeo de las DOS esquinas de arriba del navbar.
  final double radioNavbar;

  /// Redondeo de las DOS esquinas de arriba del miniplayer.
  final double radioMiniplayer;

  /// Intensidad de las OLAS del borde de arriba del navbar (0 = apenas
  /// ondula, 1 = muchas olas). Solo se usa cuando el diseño puesto en esa
  /// barra tiene adorno de olas; si no, queda guardada sin efecto.
  final double olasNavbar;

  /// Intensidad de las OLAS del borde de arriba del miniplayer.
  final double olasMiniplayer;

  /// Paleta del cofre aplicada al navbar (ver catalogo_disenos_barra). No
  /// tiene nada que ver con las esquinas: moverlas a mano deja su id en
  /// [disenoPersonalizado] pero la paleta sigue puesta.
  final String disenoNavbarId;

  /// Paleta del cofre aplicada al miniplayer (mismo criterio).
  final String disenoMiniplayerId;

  /// ADORNO del cofre puesto en el navbar: el diseño que le da el borde
  /// ondulado o una calcomanía (ver catalogo_disenos_barra). Va en su propio
  /// campo para que no pise al color ni a la forma.
  final String adornoNavbarId;

  /// Adorno del cofre puesto en el miniplayer (mismo criterio).
  final String adornoMiniplayerId;

  /// Ids de los regalos que el usuario YA abrió (para el contador de
  /// "tenés un regalo": lo desbloqueado y todavía no visto es lo que cuenta).
  final List<String> regalosVistos;

  /// Separación del eje HORIZONTAL en las cards de CANCIÓN: multiplica el
  /// hueco entre cards y el margen contra los bordes izq/der (0 = pegadas).
  final double cancionX;

  /// Separación del eje VERTICAL en las cards de canción (hueco entre filas).
  final double cancionY;

  /// Separación del eje horizontal en las cards de GRILLA (álbum/playlist/
  /// artista).
  final double grillaX;

  /// Separación del eje vertical en las cards de grilla.
  final double grillaY;

  /// Redondeo de las cards, en píxeles lógicos.
  final double radioCards;

  const PreferenciasApariencia({
    this.trazoBarra = TrazoBarra.suave,
    this.radioNavbar = 20,
    this.radioMiniplayer = 8,
    this.olasNavbar = 0.5,
    this.olasMiniplayer = 0.5,
    this.disenoNavbarId = 'paleta_regalo_100',
    this.disenoMiniplayerId = 'paleta_regalo_100',
    this.adornoNavbarId = 'paleta_regalo_100',
    this.adornoMiniplayerId = 'paleta_regalo_100',
    this.regalosVistos = const [],
    this.cancionX = 1,
    this.cancionY = 1,
    this.grillaX = 1,
    this.grillaY = 1,
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

  /// Rango admitido del redondeo de las esquinas de arriba de las barras.
  /// Llega a 40 porque el diseño "pastilla" las curva al máximo.
  static const minRadioBarra = 0.0;
  static const maxRadioBarra = 40.0;

  /// Rango de la intensidad de las olas del borde de arriba.
  static const minOlas = 0.0;
  static const maxOlas = 1.0;

  /// Cuántas olas dibuja el borde con intensidad [i] (de 2 a 6).
  static int olasDe(double i) => (2 + (i.clamp(minOlas, maxOlas) * 4)).round();

  /// Marca de "ajustado a mano": no es ningún diseño del cofre.
  static const disenoPersonalizado = 'personalizado';

  /// Separación horizontal "general": promedio de los dos componentes. Es lo
  /// que muestra el control general (y deja de ser uniforme al afinar uno).
  double get espacioX => (cancionX + grillaX) / 2;

  /// Separación vertical "general" (mismo criterio).
  double get espacioY => (cancionY + grillaY) / 2;

  /// ¿Los cuatro valores (y por lo tanto los dos ejes) van iguales? Si el
  /// usuario los separa, la UI lo marca como "Personalizado".
  bool get separacionUniforme =>
      (cancionX - grillaX).abs() < 0.001 &&
      (cancionY - grillaY).abs() < 0.001 &&
      (cancionX - cancionY).abs() < 0.001;

  /// Tramo final (cerca de 0) en el que aparece la línea divisoria del modo
  /// "unido" tipo Spotify.
  static const _anchoLinea = 0.2;

  /// Opacidad de la línea que separa las filas de CANCIÓN (eje vertical).
  double get opacidadLineaYCancion => _lineaDe(cancionY);

  /// Opacidad de la línea que separa las filas de la GRILLA.
  double get opacidadLineaYGrilla => _lineaDe(grillaY);

  /// Opacidad de la línea que separa las columnas de la GRILLA.
  double get opacidadLineaXGrilla => _lineaDe(grillaX);

  /// Opacidad "general" (promedio), para la vista previa de Ajustes.
  double get opacidadLineaY => _lineaDe(espacioY);
  double get opacidadLineaX => _lineaDe(espacioX);

  static double _lineaDe(double factor) {
    final v = (_anchoLinea - factor) / _anchoLinea;
    return v.clamp(0, 1).toDouble();
  }

  /// Copia con los campos indicados cambiados (y ya acotados).
  ///
  /// `espacioX`/`espacioY` son atajos que fijan los DOS componentes en ese
  /// eje; los campos por componente (`cancion*`/`grilla*`) pisan a los
  /// atajos y permiten afinar uno solo.
  PreferenciasApariencia copiarCon({
    TrazoBarra? trazoBarra,
    double? radioNavbar,
    double? radioMiniplayer,
    double? olasNavbar,
    double? olasMiniplayer,
    String? disenoNavbarId,
    String? disenoMiniplayerId,
    String? adornoNavbarId,
    String? adornoMiniplayerId,
    List<String>? regalosVistos,
    double? espacioX,
    double? espacioY,
    double? cancionX,
    double? cancionY,
    double? grillaX,
    double? grillaY,
    double? radioCards,
  }) {
    var cx = cancionX ?? this.cancionX;
    var cy = cancionY ?? this.cancionY;
    var gx = grillaX ?? this.grillaX;
    var gy = grillaY ?? this.grillaY;
    if (espacioX != null) {
      cx = espacioX;
      gx = espacioX;
    }
    if (espacioY != null) {
      cy = espacioY;
      gy = espacioY;
    }
    return PreferenciasApariencia(
      trazoBarra: trazoBarra ?? this.trazoBarra,
      radioNavbar: acotar(
        radioNavbar ?? this.radioNavbar,
        minRadioBarra,
        maxRadioBarra,
      ),
      radioMiniplayer: acotar(
        radioMiniplayer ?? this.radioMiniplayer,
        minRadioBarra,
        maxRadioBarra,
      ),
      olasNavbar: acotar(olasNavbar ?? this.olasNavbar, minOlas, maxOlas),
      olasMiniplayer: acotar(
        olasMiniplayer ?? this.olasMiniplayer,
        minOlas,
        maxOlas,
      ),
      disenoNavbarId: disenoNavbarId ?? this.disenoNavbarId,
      disenoMiniplayerId: disenoMiniplayerId ?? this.disenoMiniplayerId,
      adornoNavbarId: adornoNavbarId ?? this.adornoNavbarId,
      adornoMiniplayerId: adornoMiniplayerId ?? this.adornoMiniplayerId,
      regalosVistos: regalosVistos ?? this.regalosVistos,
      cancionX: acotar(cx, minEspacio, maxEspacio),
      cancionY: acotar(cy, minEspacio, maxEspacio),
      grillaX: acotar(gx, minEspacio, maxEspacio),
      grillaY: acotar(gy, minEspacio, maxEspacio),
      radioCards: acotar(radioCards ?? this.radioCards, minRadio, maxRadio),
    );
  }

  /// ¿Están todos los valores en el diseño de fábrica?
  bool get esDeFabrica =>
      trazoBarra == deFabrica.trazoBarra &&
      (radioNavbar - deFabrica.radioNavbar).abs() < 0.001 &&
      (radioMiniplayer - deFabrica.radioMiniplayer).abs() < 0.001 &&
      (olasNavbar - deFabrica.olasNavbar).abs() < 0.001 &&
      (olasMiniplayer - deFabrica.olasMiniplayer).abs() < 0.001 &&
      disenoNavbarId == deFabrica.disenoNavbarId &&
      disenoMiniplayerId == deFabrica.disenoMiniplayerId &&
      adornoNavbarId == deFabrica.adornoNavbarId &&
      adornoMiniplayerId == deFabrica.adornoMiniplayerId &&
      (cancionX - deFabrica.cancionX).abs() < 0.001 &&
      (cancionY - deFabrica.cancionY).abs() < 0.001 &&
      (grillaX - deFabrica.grillaX).abs() < 0.001 &&
      (grillaY - deFabrica.grillaY).abs() < 0.001 &&
      (radioCards - deFabrica.radioCards).abs() < 0.001;

  /// Serializa a JSON para persistencia.
  Map<String, dynamic> aJson() => {
    'trazoBarra': trazoBarra.clave,
    'radioNavbar': radioNavbar,
    'radioMiniplayer': radioMiniplayer,
    'olasNavbar': olasNavbar,
    'olasMiniplayer': olasMiniplayer,
    'disenoNavbarId': disenoNavbarId,
    'disenoMiniplayerId': disenoMiniplayerId,
    'adornoNavbarId': adornoNavbarId,
    'adornoMiniplayerId': adornoMiniplayerId,
    'regalosVistos': regalosVistos,
    'cancionX': cancionX,
    'cancionY': cancionY,
    'grillaX': grillaX,
    'grillaY': grillaY,
    'radioCards': radioCards,
  };

  /// Deserializa desde JSON (con acotado de rangos).
  factory PreferenciasApariencia.desdeJson(Map<String, dynamic> json) {
    double sep(String clave, double base) => acotar(
      (json[clave] as num?)?.toDouble() ?? base,
      minEspacio,
      maxEspacio,
    );
    double radio(String clave, double base) => acotar(
      (json[clave] as num?)?.toDouble() ?? base,
      minRadioBarra,
      maxRadioBarra,
    );
    double olas(String clave, double base) =>
        acotar((json[clave] as num?)?.toDouble() ?? base, minOlas, maxOlas);
    final vistos = json['regalosVistos'];
    return PreferenciasApariencia(
      // Se lee también la clave vieja 'bordeMiniplayer' (preferencias
      // guardadas antes de que el control pasara a las barras).
      trazoBarra: TrazoBarra.desdeClave(
        (json['trazoBarra'] ?? json['bordeMiniplayer']) as String?,
      ),
      radioNavbar: radio('radioNavbar', deFabrica.radioNavbar),
      radioMiniplayer: radio('radioMiniplayer', deFabrica.radioMiniplayer),
      olasNavbar: olas('olasNavbar', deFabrica.olasNavbar),
      olasMiniplayer: olas('olasMiniplayer', deFabrica.olasMiniplayer),
      disenoNavbarId:
          json['disenoNavbarId'] as String? ?? deFabrica.disenoNavbarId,
      disenoMiniplayerId:
          json['disenoMiniplayerId'] as String? ?? deFabrica.disenoMiniplayerId,
      adornoNavbarId:
          json['adornoNavbarId'] as String? ?? deFabrica.adornoNavbarId,
      adornoMiniplayerId:
          json['adornoMiniplayerId'] as String? ?? deFabrica.adornoMiniplayerId,
      regalosVistos:
          vistos is List
              ? vistos.whereType<String>().toList(growable: false)
              : const [],
      cancionX: sep('cancionX', deFabrica.cancionX),
      cancionY: sep('cancionY', deFabrica.cancionY),
      grillaX: sep('grillaX', deFabrica.grillaX),
      grillaY: sep('grillaY', deFabrica.grillaY),
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
