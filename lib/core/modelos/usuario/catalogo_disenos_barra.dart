// ─────────────────────────────────────────────────────────────
// catalogo_disenos_barra.dart — Modelo del catálogo de DISEÑOS del
// navbar y del miniplayer (el "cofre" de Ajustes → Barras).
//
// Modelo puro: sin widgets ni I/O. Un diseño trae hasta CINCO cosas y
// cada una es opcional, porque el cofre mezcla formas, adornos y colores:
//   paleta       → los colores ARGB con los que se tiñe la barra
//   radioArriba  → la FORMA: cuánto se curvan las dos esquinas de arriba
//                  (0 = recto, 40 = pastilla, todo curveado)
//   trazo        → el contorno de la barra (sin contorno, suave, marcado)
//   adorno       → CÓMO se dibuja el borde de arriba: esquinas (lo de
//                  siempre) u OLAS (ondula). Con olas, el deslizador deja de
//                  mover el radio y pasa a dar más o menos olas.
//   sticker      → un id de calcomanía que la barra dibuja encima ('' = no
//                  tiene). El ícono se resuelve en la capa de widgets, así
//                  este archivo sigue siendo puro.
//
// Un diseño puede traer solo una cosa ("Recto", "Aurora", "Destello") o
// varias. Lo que NO trae, no se toca: aplicar "Recto" deja intacto el color
// que ya tenías, y aplicar "Aurora" deja intacta la forma.
//
// Los nombres NO viven acá: son texto localizado (StringsCofrePaletas).
//
// La LISTA de diseños y el contador de regalos viven en
// catalogo_disenos_barra_lista.dart (que reexporta este archivo); cuándo se
// abre un diseño, en catalogo_disenos_barra_desbloqueo.dart.
//
// Un diseño se consigue de tres maneras:
//   libre   → ya lo tenés (el de fábrica, el regalo que trae la app)
//   horas   → por horas de escucha acumuladas (misma escalera que los
//             niveles: de 1 h a 3.000 h)
//   version → llega con una versión concreta de la app
//
// Se conecta con: catalogo_disenos_barra_lista.dart (la lista) +
// preferencias_apariencia.dart (guarda la forma, el contorno, el color
// y los regalos ya abiertos) + el cofre de Ajustes.
// Parte del flujo: Ajustes → Apariencia → Barras.
// ─────────────────────────────────────────────────────────────

import 'preferencias_apariencia.dart';

/// Cómo se consigue un diseño.
enum DesbloqueoBarra {
  /// Ya disponible de fábrica.
  libre('libre'),

  /// Por horas de escucha acumuladas.
  horas('horas'),

  /// Llega con una versión de la app.
  version('version');

  final String clave;
  const DesbloqueoBarra(this.clave);
}

/// Cómo se dibuja el borde de arriba de la barra.
enum AdornoBarra {
  /// Esquinas rectas o curveadas, según el radio (lo de siempre).
  esquinas('esquinas'),

  /// Olas: el borde de arriba ondula. El control pasa a dar más o menos olas.
  olas('olas');

  final String clave;
  const AdornoBarra(this.clave);
}

/// Un diseño de barra: forma, color, contorno, adorno y sticker, todo opcional.
class DisenoBarra {
  /// Identificador estable (se guarda en las preferencias).
  final String id;

  /// Cómo se consigue.
  final DesbloqueoBarra desbloqueo;

  /// Horas requeridas (si [desbloqueo] es `horas`) o versión en número
  /// (si es `version`, ver [versionEnNumero]).
  final int valor;

  /// Colores ARGB de la paleta, de 1 a 3. Vacía = NO TIÑE: la barra queda
  /// con su color de siempre.
  final List<int> paleta;

  /// Redondeo de las DOS esquinas de arriba. `null` = no toca la forma.
  /// 0 es recto y 40 (ver maxRadioBarra) es la pastilla, todo curveado.
  final double? radioArriba;

  /// Contorno que pone el diseño. `null` = no toca el contorno.
  final TrazoBarra? trazo;

  /// Cómo se dibuja el borde de arriba. `esquinas` = no toca nada.
  final AdornoBarra adorno;

  /// Id de la calcomanía que la barra dibuja encima. '' = no tiene.
  final String sticker;

  /// Versión con la que LLEGÓ el diseño cuando es un regalo de
  /// actualización ya disponible (p. ej. '1.0.0'). Vacío = no lo declara.
  final String llegoConVersion;

  const DisenoBarra({
    required this.id,
    this.desbloqueo = DesbloqueoBarra.libre,
    this.valor = 0,
    this.paleta = const [],
    this.radioArriba,
    this.trazo,
    this.adorno = AdornoBarra.esquinas,
    this.sticker = '',
    this.llegoConVersion = '',
  });

  /// ¿El diseño tiñe la barra?
  bool get tienePaleta => paleta.isNotEmpty;

  /// ¿El diseño le cambia la forma a las esquinas de arriba?
  bool get tieneForma => radioArriba != null;

  /// ¿El diseño le cambia el contorno a la barra?
  bool get tieneTrazo => trazo != null;

  /// ¿El diseño le cambia el BORDE de arriba (olas en vez de esquinas)?
  bool get tieneAdorno => adorno != AdornoBarra.esquinas;

  /// ¿El diseño le pone una calcomanía a la barra?
  bool get tieneSticker => sticker.isNotEmpty;

  /// ¿Trae algo? Un diseño que no trae nada no sirve para nada.
  bool get traeAlgo =>
      tienePaleta || tieneForma || tieneTrazo || tieneAdorno || tieneSticker;
}
