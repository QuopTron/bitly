// ─────────────────────────────────────────────────────────────
// strings_cofre_paletas.dart — Textos del COFRE DE DISEÑOS de Ajustes →
// Apariencia → Barras: el título, el estado de cada diseño ("En uso",
// "Usar", cuántas horas faltan o con qué versión llega) y su nombre.
//
// Los nombres se resuelven por ID con un MAPA por idioma: el catálogo es
// puro (forma, color, aparato y condiciones) y el texto vive acá, así un
// idioma nuevo no obliga a tocar el modelo ni un switch.
//
// Las frases con datos (cuántos regalos, cuántas horas, qué aparato) son
// PLANTILLAS por idioma, no texto español incrustado: el inglés tiene las
// suyas. Las instancias (cofreEs / cofreEn) viven en
// strings_cofre_paletas_idiomas.dart para que cada archivo siga chico.
//
// Se conecta con: app_localizations.dart (lo expone como `cofre`) y el
// cofre de settings_sheet_appearance_barras_cofre.
// Parte del flujo: Ajustes → Apariencia → Barras.
// ─────────────────────────────────────────────────────────────

class StringsCofrePaletas {
  /// Título del espacio.
  final String titulo;

  /// Ayuda corta: qué es el cofre.
  final String ayuda;

  /// Botón que abre el submodal del cofre.
  final String abrir;

  /// Botón que lo cierra.
  final String listo;

  /// Estado del diseño que ya está puesto en la barra.
  final String enUso;

  /// Acción de un diseño que ya se puede usar.
  final String usar;

  /// Cuando no queda ningún regalo por abrir.
  final String todoVisto;

  /// Encabezado de los regalos por abrir.
  final String regalosTitulo;

  /// Título de la sección de formas y adornos.
  final String seccionDisenos;

  /// Título de la sección de paletas de color.
  final String seccionColores;

  /// Nombre de cada diseño del catálogo, por id (ver
  /// catalogo_disenos_barra_lista). Un id que no esté cae a sí mismo.
  final Map<String, String> nombres;

  /// Plantillas: llevan %n (número), %v (versión) o %a (aparato).
  final String _tplUnRegalo;
  final String _tplRegalos;
  final String _tplHoras;
  final String _tplVersion;
  final String _tplViene;
  final String _tplAparato;

  const StringsCofrePaletas({
    required this.titulo,
    required this.ayuda,
    required this.abrir,
    required this.listo,
    required this.enUso,
    required this.usar,
    required this.todoVisto,
    required this.regalosTitulo,
    required this.seccionDisenos,
    required this.seccionColores,
    required this.nombres,
    required String tplUnRegalo,
    required String tplRegalos,
    required String tplHoras,
    required String tplVersion,
    required String tplViene,
    required String tplAparato,
  }) : _tplUnRegalo = tplUnRegalo,
       _tplRegalos = tplRegalos,
       _tplHoras = tplHoras,
       _tplVersion = tplVersion,
       _tplViene = tplViene,
       _tplAparato = tplAparato;

  /// "Tenés 1 regalo por abrir" / "You have 1 gift to open".
  String regalos(int n) =>
      (n == 1 ? _tplUnRegalo : _tplRegalos).replaceFirst('%n', '$n');

  /// "Se abre con 50 h de escucha" / "Opens with 50 h of listening".
  String horas(int horas) => _tplHoras.replaceFirst('%n', '$horas');

  /// "Llega con la versión 0.9.23" / "Arrives with version 0.9.23".
  String llegaConVersion(String version) =>
      _tplVersion.replaceFirst('%v', version);

  /// "Viene con la v1.0.0" — el regalo que ya trae la app.
  String vieneCon(String version) => _tplViene.replaceFirst('%v', version);

  /// "Diseños para tu Celular": a qué aparato pertenece lo que se ve.
  String paraAparato(String aparato) => _tplAparato.replaceFirst('%a', aparato);

  /// Nombre del diseño [id] (formas, adornos, colores y los de aparato).
  String nombre(String id) => nombres[id] ?? id;
}
