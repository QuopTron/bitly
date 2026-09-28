// ─────────────────────────────────────────────────────────────
// strings_vistas.dart — Textos de Ajustes → Apariencia → VISTAS: el diseño
// propio de cada pantalla (Inicio, Búsqueda, Mi Espacio, Detalle, Reproductor,
// Ajustes y Tutorial).
//
// Igual que en el cofre de las barras y en las tipografías, los NOMBRES se
// resuelven por ID con un mapa por idioma: el enum VistaApp queda puro (sólo
// claves estables) y el texto vive acá, así un idioma nuevo no obliga a tocar
// el modelo.
//
// Las frases con números son PLANTILLAS por idioma, no texto español
// incrustado. Las instancias (vistasEs / vistasEn) viven en
// strings_vistas_idiomas.dart para que cada archivo siga chico.
//
// Se conecta con: app_localizations.dart (lo expone como `vistas`) y la
// tarjeta de vistas de settings_sheet_appearance_vistas.
// Parte del flujo: Ajustes → Apariencia → Vistas.
// ─────────────────────────────────────────────────────────────

class StringsVistas {
  /// Título del bloque.
  final String titulo;

  /// Bajada corta: qué se puede hacer acá.
  final String ayuda;

  /// Acción para que la vista vuelva a heredar todo.
  final String heredar;

  /// Estado de un eje que la vista NO tocó.
  final String heredado;

  /// Estado de un eje que la vista SÍ tocó.
  final String propio;

  /// Botón que devuelve la vista entera al estilo global.
  final String restablecer;

  /// Confirmación de que se restableció.
  final String restablecida;

  /// Aviso de que la vista elegida no tiene nada propio.
  final String sinCambios;

  /// Rótulo del eje de tipografía.
  final String tipografia;

  /// Rótulo del eje de redondeo de las cards.
  final String radio;

  /// Rótulo del eje de densidad de espacios.
  final String densidad;

  /// Rótulo del eje de columnas de la grilla.
  final String columnas;

  /// Rótulos CORTOS de las pestañas de eje. Cada eje tiene su pestaña para
  /// que la tarjeta no sea un rollo interminable, y el rótulo largo del eje se
  /// ve adentro de la pestaña que se abre.
  final String ejeColor;
  final String ejeLetra;
  final String ejeForma;
  final String ejeAire;
  final String ejeGrilla;

  /// Rótulo del eje de color de las tarjetas (la paleta del cofre).
  final String cofre;

  /// Qué hace la paleta en esta pantalla (para que no quede la duda de qué
  /// tiñe: son las tarjetas de esta vista, no toda la app).
  final String cofreAyuda;

  /// Opción sin paleta: las tarjetas se tiñen con el color de su carátula,
  /// que es lo de siempre.
  final String cofreCover;

  /// Valor "sin tope" de un eje que no hereda del global sino que se resuelve
  /// solo (las columnas las decide el ancho de la pantalla).
  final String automatico;

  /// Se está bajando la tipografía que eligió esta vista.
  final String bajandoTipografia;

  /// La bajada de esa tipografía falló: la vista sigue con la de la app.
  final String sinTipografia;

  /// Nombre de cada vista, por clave de VistaApp (ver vista_app.dart). Una
  /// clave que no esté cae a sí misma.
  final Map<String, String> nombres;

  /// Plantilla: lleva %n (cuántas vistas tienen diseño propio).
  final String _tplTocadas;

  const StringsVistas({
    required this.titulo,
    required this.ayuda,
    required this.heredar,
    required this.heredado,
    required this.propio,
    required this.restablecer,
    required this.restablecida,
    required this.sinCambios,
    required this.tipografia,
    required this.radio,
    required this.densidad,
    required this.columnas,
    required this.ejeColor,
    required this.ejeLetra,
    required this.ejeForma,
    required this.ejeAire,
    required this.ejeGrilla,
    required this.cofre,
    required this.cofreAyuda,
    required this.cofreCover,
    required this.automatico,
    required this.bajandoTipografia,
    required this.sinTipografia,
    required this.nombres,
    required String tplTocadas,
  }) : _tplTocadas = tplTocadas;

  /// "2 pantallas con diseño propio" / "2 screens with their own design".
  String tocadas(int n) => _tplTocadas.replaceFirst('%n', '$n');

  /// Nombre de la vista con [clave] (la clave cruda si no está declarada).
  String nombre(String clave) => nombres[clave] ?? clave;
}
