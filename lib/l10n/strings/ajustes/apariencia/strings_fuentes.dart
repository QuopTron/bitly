// ─────────────────────────────────────────────────────────────
// strings_fuentes.dart — Textos de Ajustes → Apariencia → TIPOGRAFÍA: el
// título, el estado de cada fuente ("En uso", "Usar", cuántas horas faltan o
// con qué versión llega) y su nombre.
//
// Igual que en el cofre de las barras, los NOMBRES se resuelven por ID con un
// mapa por idioma: el catálogo queda puro (familia, URL y condiciones) y el
// texto vive acá, así un idioma nuevo no obliga a tocar el modelo.
//
// Las frases con datos (cuántas horas, qué versión) son PLANTILLAS por idioma,
// no texto español incrustado: el inglés tiene las suyas. Las instancias
// (fuentesEs / fuentesEn) viven en strings_fuentes_idiomas.dart para que cada
// archivo siga chico.
//
// Se conecta con: app_localizations.dart (lo expone como `fuentes`) y la
// tarjeta de tipografía de settings_sheet_appearance_tipografia.
// Parte del flujo: Ajustes → Apariencia → Tipografía.
// ─────────────────────────────────────────────────────────────

class StringsFuentes {
  /// Título del bloque.
  final String titulo;

  /// Bajada corta: qué se puede hacer acá.
  final String ayuda;

  /// Estado de la fuente que ya está puesta.
  final String enUso;

  /// Acción de una fuente que ya se puede usar.
  final String usar;

  /// Estado mientras se baja.
  final String descargando;

  /// Rótulo del recuadro de la previa en vivo.
  final String previaTitulo;

  /// El texto de muestra de la previa.
  final String previaTexto;

  /// La bajada falló (sin red o espejo caído).
  final String sinRed;

  /// Botón para reintentar una bajada que falló.
  final String reintentar;

  /// Botón que borra las tipografías bajadas.
  final String liberar;

  /// Confirmación de que se borraron.
  final String liberado;

  /// Nombre de cada fuente del catálogo, por id (ver catalogo_fuentes). Un id
  /// que no esté cae a sí mismo.
  final Map<String, String> nombres;

  /// Plantillas: llevan %n (horas) o %v (versión).
  final String _tplHoras;
  final String _tplVersion;

  const StringsFuentes({
    required this.titulo,
    required this.ayuda,
    required this.enUso,
    required this.usar,
    required this.descargando,
    required this.previaTitulo,
    required this.previaTexto,
    required this.sinRed,
    required this.reintentar,
    required this.liberar,
    required this.liberado,
    required this.nombres,
    required String tplHoras,
    required String tplVersion,
  }) : _tplHoras = tplHoras,
       _tplVersion = tplVersion;

  /// "Se abre con 50 h de escucha" / "Opens with 50 h of listening".
  String horas(int horas) => _tplHoras.replaceFirst('%n', '$horas');

  /// "Llega con la versión 1.0.0" / "Arrives with version 1.0.0".
  String llegaConVersion(String version) =>
      _tplVersion.replaceFirst('%v', version);

  /// Nombre de la fuente [id] (el id crudo si el catálogo no la declara).
  String nombre(String id) => nombres[id] ?? id;
}
