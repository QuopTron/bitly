// ─────────────────────────────────────────────────────────────
// diseno_vista.dart — Qué puede cambiar UNA vista por su cuenta.
//
// Todo campo vacío ('' o null) significa NO TOCA: la vista hereda ese eje del
// estilo global del usuario. Es la misma regla del cofre de las barras —"lo
// que el diseño no trae, no se toca"— pero extendida a cada eje de diseño:
// conjunto (color/forma/adorno), tipografía, card, fondo, radio, densidad y
// columnas.
//
// Por qué importa: es lo que permite personalización extrema SIN que la app
// quede incoherente. El que no toca nada ve la app como siempre (todo
// hereda); el que quiere, cambia SOLO lo que le interesa de una vista.
//
// Los ids no se validan acá (el modelo es puro): resolverlos es trabajo del
// catálogo y del helper de vistas.
//
// Se conecta con: vista_app.dart (a cuál pertenece) +
// preferencias_vistas.dart (dónde se guarda) + preferencias_vistas_json.dart
// (cómo se serializa).
// Parte del flujo: Ajustes → Apariencia → Vistas.
// ─────────────────────────────────────────────────────────────

import '../../preferencias/preferencias_apariencia.dart' show acotar;

/// Sobrescrituras de diseño de una vista. Vacío = hereda todo.
class DisenoVista {
  /// Id del diseño del catálogo puesto en esta vista. Ese diseño puede traer
  /// color, forma, adorno y sticker (ver catalogo_disenos_barra.dart).
  /// '' = los hereda del estilo global.
  ///
  /// Hoy sólo se consume su PALETA: tiñe las cards de esta pantalla. Por eso
  /// Ajustes ofrece únicamente las paletas del cofre —exponer las formas sería
  /// un control que no hace nada—, aunque el campo guarde el id del diseño
  /// entero para que el día que la forma también se consuma no haya que migrar
  /// nada de lo ya guardado.
  final String disenoId;

  /// Familia tipográfica de la vista. '' = la global.
  final String tipografiaId;

  /// Estilo de las cards de la vista (borde, sombra, relleno). '' = el global.
  final String estiloCardId;

  /// Fondo de la vista. '' = el global.
  final String fondoId;

  /// Redondeo propio de las cards, en píxeles lógicos. null = el global.
  final double? radioTarjeta;

  /// Multiplicador de DENSIDAD de espacios sobre el global. null = 1 (igual).
  /// Por debajo de 1 la vista se aprieta; por arriba, respira más.
  final double? densidad;

  /// Nº máximo de columnas de las grillas de la vista. 0 = automático (lo de
  /// hoy: lo decide cada grilla por el ancho disponible).
  final int columnasMax;

  const DisenoVista({
    this.disenoId = '',
    this.tipografiaId = '',
    this.estiloCardId = '',
    this.fondoId = '',
    this.radioTarjeta,
    this.densidad,
    this.columnasMax = 0,
  });

  /// Sin tocar nada: la vista queda igual que el estilo global.
  static const hereda = DisenoVista();

  /// Rango de la densidad: por debajo se aprieta demasiado y por arriba las
  /// cards de tamaño fijo se desbordan (mismo criterio que la escala).
  static const minDensidad = 0.6;
  static const maxDensidad = 1.5;

  /// Tope de columnas: más de 8 y las portadas quedan del tamaño de un sello.
  static const maxColumnas = 8;

  /// ¿No toca nada? Entonces la vista no se guarda y hereda entera.
  bool get esHereda =>
      disenoId.isEmpty &&
      tipografiaId.isEmpty &&
      estiloCardId.isEmpty &&
      fondoId.isEmpty &&
      radioTarjeta == null &&
      densidad == null &&
      columnasMax == 0;

  /// ¿La vista eligió su propio conjunto (color, forma, adorno y sticker)?
  bool get tocaConjunto => disenoId.isNotEmpty;

  /// ¿La vista aprieta o airea sus espacios?
  bool get tocaDensidad => densidad != null;

  /// Copia con los ejes indicados cambiados (y ya acotados).
  ///
  /// `borrarRadio` / `borrarDensidad` vuelven el eje a "hereda": pasar null no
  /// alcanza para eso, porque null justamente significa "no tocar".
  DisenoVista copiarCon({
    String? disenoId,
    String? tipografiaId,
    String? estiloCardId,
    String? fondoId,
    double? radioTarjeta,
    double? densidad,
    int? columnasMax,
    bool borrarRadio = false,
    bool borrarDensidad = false,
  }) {
    return DisenoVista(
      disenoId: disenoId ?? this.disenoId,
      tipografiaId: tipografiaId ?? this.tipografiaId,
      estiloCardId: estiloCardId ?? this.estiloCardId,
      fondoId: fondoId ?? this.fondoId,
      radioTarjeta: borrarRadio
          ? null
          : (radioTarjeta == null
                ? this.radioTarjeta
                : acotar(radioTarjeta, minRadio, maxRadio)),
      densidad: borrarDensidad
          ? null
          : (densidad == null
                ? this.densidad
                : acotar(densidad, minDensidad, maxDensidad)),
      columnasMax: columnasMax == null
          ? this.columnasMax
          : (columnasMax < 0 ? 0 : (columnasMax > maxColumnas ? maxColumnas : columnasMax)),
    );
  }

  /// Rango del redondeo de las cards (el mismo que el control global).
  static const minRadio = 0.0;
  static const maxRadio = 28.0;

  /// Serializa a JSON para persistencia.
  Map<String, dynamic> aJson() => {
    'disenoId': disenoId,
    'tipografiaId': tipografiaId,
    'estiloCardId': estiloCardId,
    'fondoId': fondoId,
    if (radioTarjeta != null) 'radioTarjeta': radioTarjeta,
    if (densidad != null) 'densidad': densidad,
    if (columnasMax > 0) 'columnasMax': columnasMax,
  };

  /// Deserializa desde JSON, acotando los rangos y tolerando basura: una
  /// preferencia vieja o rota deja la vista heredando, nunca rompe el arranque.
  factory DisenoVista.desdeJson(Map<String, dynamic> json) {
    final radio = (json['radioTarjeta'] as num?)?.toDouble();
    final dens = (json['densidad'] as num?)?.toDouble();
    final cols = (json['columnasMax'] as num?)?.toInt() ?? 0;
    return DisenoVista(
      disenoId: _texto(json, 'disenoId'),
      tipografiaId: _texto(json, 'tipografiaId'),
      estiloCardId: _texto(json, 'estiloCardId'),
      fondoId: _texto(json, 'fondoId'),
      radioTarjeta: radio == null ? null : acotar(radio, minRadio, maxRadio),
      densidad: dens == null ? null : acotar(dens, minDensidad, maxDensidad),
      columnasMax: cols <= 0 ? 0 : (cols > maxColumnas ? maxColumnas : cols),
    );
  }

  /// Lee un id de texto del mapa ('' si falta o no es texto).
  static String _texto(Map<String, dynamic> json, String clave) {
    final v = json[clave];
    return v is String ? v : '';
  }
}
