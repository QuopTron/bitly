// ─────────────────────────────────────────────────────────────
// release_notas.dart — Las notas de una release de GitHub leídas como
// TEXTO, no como el markdown crudo que devuelve la API.
//
// Por qué existe: la hoja de versiones mostraba las notas tal cual venían
// (`### ✨ Novedades`, `**algo**: ...`, la versión en español y en inglés
// pegadas una atrás de la otra) y, peor, cualquier símbolo raro del markdown
// se colaba a la vista. El usuario veía un muro de texto con almohadillas y
// asteriscos en vez de "qué hay de nuevo".
//
// Qué hace: parte el cuerpo en BLOQUES con título (las secciones de las notas)
// y sus viñetas, saca los símbolos del markdown, junta las líneas de un mismo
// ítem y se queda con UN solo idioma (el de la app: las notas del proyecto
// vienen en español y después en inglés, separadas por `---`).
//
// Además descarta lo que no es "novedad": el encabezado que repite el nombre y
// la versión, y el bloque de descargas (los archivos ya están en el botón de
// descarga de la release).
//
// Es un archivo normal (no una PART de la hoja) porque lo usan DOS librarys:
// la hoja de versiones (Ajustes → Más) y la hoja de actualización.
//
// Se conecta con: release_notas_vista.dart (lo dibuja) + la API de releases.
// Parte del flujo: Ajustes → Versión (novedades).
// ─────────────────────────────────────────────────────────────

/// Una viñeta de las notas.
///
/// El destacado en negrita del principio (`**Título**: resto`) se guarda
/// aparte: así el título se puede pintar con más peso y el resto como texto
/// normal, en vez de perder la jerarquía al sacar los asteriscos.
class ItemNotas {
  /// Lo que venía en negrita al principio. Vacío si la viñeta es texto suelto.
  final String titulo;

  /// El resto de la viñeta (sin el título).
  final String texto;

  const ItemNotas({this.titulo = '', this.texto = ''});

  const ItemNotas.vacio() : titulo = '', texto = '';

  bool get vacio => titulo.isEmpty && texto.isEmpty;
}

/// Una sección de las notas: su título y sus viñetas.
class BloqueNotas {
  final String titulo;
  final List<ItemNotas> items;

  const BloqueNotas({this.titulo = '', this.items = const []});

  bool get vacio => titulo.isEmpty && items.isEmpty;
}

/// Las notas de una release, ya limpias.
class NotasRelease {
  final List<BloqueNotas> bloques;

  const NotasRelease(this.bloques);

  /// Notas ausentes o vacías: la vista no dibuja nada.
  static const NotasRelease sinNotas = NotasRelease(<BloqueNotas>[]);

  bool get vacias => bloques.isEmpty;

  /// Cuántas viñetas hay en total (lo usa "Ver todo" para saber si recortar).
  int get total => bloques.fold<int>(0, (suma, b) => suma + b.items.length);

  /// Lee el cuerpo de una release y devuelve sus bloques.
  ///
  /// [esEspanol] elige el idioma: las notas del proyecto traen primero el
  /// español y después el inglés, separados por una línea `---`. Si el cuerpo
  /// tiene un solo idioma se usa ese, sin importar cuál se pidió.
  /// [version] sirve para descartar el encabezado que repite la versión.
  static NotasRelease parsear(
    String cuerpo, {
    required bool esEspanol,
    String version = '',
  }) {
    final texto = cuerpo.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final partes = _partesPorIdioma(texto);
    if (partes.isEmpty) return sinNotas;
    final elegido =
        partes.length == 1
            ? partes.first
            : (esEspanol ? partes.first : partes.last);

    final bloques = <BloqueNotas>[];
    var titulo = '';
    var items = <ItemNotas>[];

    void cerrar() {
      if (titulo.isNotEmpty || items.isNotEmpty) {
        bloques.add(BloqueNotas(titulo: titulo, items: items));
      }
      titulo = '';
      items = <ItemNotas>[];
    }

    var fueVineta = false;
    for (final cruda in elegido.split('\n')) {
      final linea = cruda.trim();
      if (linea.isEmpty || _esSeparador(linea)) continue;

      final encabezado = _tituloDeEncabezado(linea);
      if (encabezado != null) {
        cerrar();
        titulo = limpiarInline(encabezado);
        fueVineta = false;
        continue;
      }

      final vineta = _textoDeVineta(linea);
      if (vineta != null) {
        items.add(_item(vineta));
        fueVineta = true;
        continue;
      }

      // Párrafo suelto: si la línea de arriba seguía el mismo párrafo (las
      // notas cortan una frase al medio), se pega en vez de cortar la idea.
      final item = _item(linea);
      if (!fueVineta && items.isNotEmpty) {
        final anterior = items.removeLast();
        items.add(
          ItemNotas(
            titulo: anterior.titulo,
            texto: '${anterior.texto} ${item.texto}'.trim(),
          ),
        );
      } else {
        items.add(item);
      }
      fueVineta = false;
    }
    cerrar();

    return NotasRelease(_sinRuido(bloques, version));
  }

  /// Saca lo que no cuenta como novedad:
  ///   · el encabezado que repite el nombre de la app y la versión,
  ///   · el bloque de descargas (los archivos están en el botón de la release),
  ///   · bloques que quedaron sin nada.
  static List<BloqueNotas> _sinRuido(
    List<BloqueNotas> bloques,
    String version,
  ) {
    final limpios = <BloqueNotas>[];
    for (final b in bloques) {
      final titulo = b.titulo.trim();
      final items = b.items.where((i) => !i.vacio).toList();

      final anuncio =
          titulo.contains('🎵') ||
          (b.titulo.isEmpty &&
              items.isNotEmpty &&
              version.isNotEmpty &&
              items.first.texto.contains(version) &&
              bloques.length == 1);
      if (anuncio) continue;

      if (_esDeDescargas(titulo)) continue;

      if (titulo.isEmpty && items.isEmpty) continue;
      limpios.add(BloqueNotas(titulo: titulo, items: items));
    }
    return limpios;
  }

  /// ¿El título del bloque habla de las descargas? (No son novedades.)
  static bool _esDeDescargas(String titulo) {
    final t = titulo.toLowerCase();
    return t.contains('descarga') ||
        t.contains('download') ||
        t.contains('instal');
  }

  /// Corta el cuerpo por las líneas `---`: un bloque por idioma.
  static List<String> _partesPorIdioma(String texto) {
    final partes = <String>[];
    final actual = <String>[];
    for (final linea in texto.split('\n')) {
      if (_esSeparador(linea.trim())) {
        final parte = actual.join('\n').trim();
        if (parte.isNotEmpty) partes.add(parte);
        actual.clear();
        continue;
      }
      actual.add(linea);
    }
    final ultima = actual.join('\n').trim();
    if (ultima.isNotEmpty) partes.add(ultima);
    return partes;
  }

  /// `---`, `***` o `___` solos en su línea: separador, no contenido.
  static bool _esSeparador(String linea) =>
      RegExp(r'^([-*_])\1{2,}$').hasMatch(linea);

  /// `## Título` → `Título`. null si la línea no es un encabezado.
  static String? _tituloDeEncabezado(String linea) {
    final m = RegExp(r'^#{1,6}\s*(.+)$').firstMatch(linea);
    return m?.group(1)?.trim();
  }

  /// `- algo`, `* algo` o `+ algo` → `algo`. null si no es una viñeta.
  static String? _textoDeVineta(String linea) {
    final m = RegExp(r'^[-*+]\s+(.+)$').firstMatch(linea);
    return m?.group(1)?.trim();
  }

  /// Una viñeta: separa el negrita del principio del resto.
  static ItemNotas _item(String crudo) {
    final m = RegExp(r'^(\*\*|__)(.+?)\1\s*[:\-—–]?\s*(.*)$').firstMatch(crudo);
    if (m != null) {
      return ItemNotas(
        titulo: limpiarInline(m.group(2) ?? ''),
        texto: limpiarInline(m.group(3) ?? ''),
      );
    }
    return ItemNotas(texto: limpiarInline(crudo));
  }

  /// Saca los símbolos del markdown en línea.
  ///
  /// Además borra el rastro de las notas autogeneradas de GitHub
  /// ("... by @usuario in https://github.com/..."): no le dice nada a nadie.
  static String limpiarInline(String texto) {
    var s = texto;
    s = s.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ''); // imágenes
    s = s.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]*\)'),
      (m) => m.group(1) ?? '',
    ); // enlaces → su texto
    s = s.replaceAll(RegExp(r'\*\*|__'), ''); // negrita
    s = s.replaceAll(RegExp(r'\*'), ''); // itálica suelta
    s = s.replaceAll('`', ''); // código
    s = s.replaceAll(
      RegExp(r'\s+by\s+@[\w-]+(\s+in\s+https?://\S+)?', caseSensitive: false),
      '',
    );
    s = s.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    return s.trim();
  }
}
