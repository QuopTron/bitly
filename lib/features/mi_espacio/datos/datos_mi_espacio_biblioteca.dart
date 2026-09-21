// ─────────────────────────────────────────────────────────────
// datos_mi_espacio_biblioteca.dart — PART de datos_mi_espacio.dart:
// índice de la biblioteca local (álbumes, canciones y artistas) por
// ID normalizado y las reglas puras de respaldo — nombre y carátula
// de un ítem caen a la biblioteca cuando su registro de like o de
// descarga perdió esos datos.
// Se conecta con: datos_mi_espacio.dart (misma library) +
// ContentDao + caratula_util.
// Parte del flujo: Home → Mi Espacio (carátulas y nombres).
// ─────────────────────────────────────────────────────────────

part of 'datos_mi_espacio.dart';

/// Nombre y carátula de un ítem según la biblioteca local.
class DatoBiblioteca {
  final String nombre;
  final String caratula;

  const DatoBiblioteca({this.nombre = '', this.caratula = ''});
}

/// Carátula para mostrar: la del ítem si sirve (URL o archivo local que
/// existe de verdad) y, si no, la de la biblioteca.
String? caratulaDeItem(String? caratula, DatoBiblioteca? dato) =>
    mejorCaratula(caratula, dato?.caratula);

/// Nombre para mostrar: el del ítem y, si viene vacío, el de la
/// biblioteca; [respaldo] (normalmente el id) cierra la cadena.
String nombreDeItem(
  String? nombre,
  DatoBiblioteca? dato, {
  String respaldo = '',
}) {
  final propio = nombre?.trim() ?? '';
  if (propio.isNotEmpty) return propio;
  final deBiblioteca = dato?.nombre.trim() ?? '';
  if (deBiblioteca.isNotEmpty) return deBiblioteca;
  return respaldo;
}

/// Índice de la biblioteca local ya cargado (vacío hasta el primer
/// [refrescarBibliotecaLocal]). Se lee sincrónicamente en cada build.
Map<String, DatoBiblioteca> _bibliotecaLocal = const {};

/// Índice de la biblioteca local listo para usar (nombre + carátula por
/// ID normalizado). Es la red de seguridad de las tarjetas.
Map<String, DatoBiblioteca> get bibliotecaLocal => _bibliotecaLocal;

/// (Re)carga el índice de la biblioteca local. La llama la página al
/// abrir Mi Espacio y al cambiar de pestaña: es barato (una lectura de
/// las tablas locales) y así una descarga recién terminada ya trae su
/// portada al volver a la lista.
Future<void> refrescarBibliotecaLocal() async {
  _bibliotecaLocal = await cargarBibliotecaLocal();
}

/// Índice de la biblioteca local por ID normalizado.
///
/// Es la última red de seguridad de Mi Espacio: un lote descargado sin
/// carátula, o un like cuya portada ya no está en disco, igual muestra
/// nombre y portada porque el álbum/canción sigue guardado en la base.
Future<Map<String, DatoBiblioteca>> cargarBibliotecaLocal() async {
  final mapa = <String, DatoBiblioteca>{};
  try {
    final dao = ContentDao(sl<AppDatabase>());
    void registrar(String id, String nombre, String? ruta, String? url) {
      final clave = normalizarIdTrack(id);
      if (clave.isEmpty) return;
      final nombreLimpio = nombre.trim();
      final caratula = mejorCaratula(ruta, url) ?? '';
      if (nombreLimpio.isEmpty && caratula.isEmpty) return;
      final previo = mapa[clave];
      // Gana el que trae carátula; entre iguales se conserva el primero.
      if (previo == null || (previo.caratula.isEmpty && caratula.isNotEmpty)) {
        mapa[clave] = DatoBiblioteca(nombre: nombreLimpio, caratula: caratula);
      }
    }

    for (final a in await dao.getAlbumesBiblioteca()) {
      registrar(a.id, a.name, a.coverPath, a.coverUrl);
    }
    for (final t in await dao.getTracksBiblioteca()) {
      registrar(t.id, t.name, t.coverPath, t.coverUrl);
    }
    for (final ar in await dao.getArtistasBiblioteca()) {
      registrar(ar.id, ar.name, ar.imagePath, ar.imageUrl);
    }
  } catch (e) {
    debugPrint('[MiEspacio] biblioteca local: $e');
  }
  return mapa;
}
