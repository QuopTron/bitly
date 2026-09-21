// ─────────────────────────────────────────────────────────────
// estado_like.dart — Estado del cubit de likes: huellas de items
// amados, datos de todos los favoritos y su flag de carga.
// Incluye el helper para limpiar rutas locales de carátula viejas.
// Se conecta con: LikeCubit (estado del cubit).
// Parte del flujo: Mi Espacio → Favoritos y botones de like.
// ─────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

import '../../../shared/utilidades/portada/base/caratula_util.dart';

/// Devuelve [path] solo si es una ruta local de carátula usable.
///
/// Dos casos la descartan (y la tarjeta usa la carátula de red):
/// 1. filas legacy con la URL HTTP del caché de escritorio
///    (http://127.0.0.1:55009/cover/...) que no existe en móvil;
/// 2. rutas que apuntan a un archivo que YA NO ESTÁ en disco (instalación
///    vieja, carpeta movida, guardado fallido). Sin esto el like "tapaba"
///    con un path muerto la URL remota que sí funcionaba.
String? limpiarRutaCaratulaLocal(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.contains('127.0.0.1')) return null;
  return caratulaLocalUsable(path) ? path : null;
}

class DatosItemAmado {
  final String id;
  final String type;
  final String name;
  final String? artists;
  final String? coverUrl;
  final String? rutaCaratulaLocal;
  final String? source;
  final String? albumName;
  final int? durationMs;
  final String? isrc;

  const DatosItemAmado({
    required this.id,
    required this.type,
    required this.name,
    this.artists,
    this.coverUrl,
    this.rutaCaratulaLocal,
    this.source,
    this.albumName,
    this.durationMs,
    this.isrc,
  });

  DatosItemAmado copiarCon({String? rutaCaratulaLocal}) => DatosItemAmado(
    id: id,
    type: type,
    name: name,
    artists: artists,
    coverUrl: coverUrl,
    rutaCaratulaLocal: rutaCaratulaLocal ?? this.rutaCaratulaLocal,
    source: source,
    albumName: albumName,
    durationMs: durationMs,
    isrc: isrc,
  );
}

class EstadoLikes extends Equatable {
  final bool cargando;
  final Set<String> huellasAmadas;
  final Map<String, DatosItemAmado> todosAmados;

  const EstadoLikes({
    this.cargando = false,
    this.huellasAmadas = const {},
    this.todosAmados = const {},
  });

  EstadoLikes copiarCon({
    bool? cargando,
    Set<String>? huellasAmadas,
    Map<String, DatosItemAmado>? todosAmados,
  }) => EstadoLikes(
    cargando: cargando ?? this.cargando,
    huellasAmadas: huellasAmadas ?? this.huellasAmadas,
    todosAmados: todosAmados ?? this.todosAmados,
  );

  @override
  List<Object?> get props => [cargando, huellasAmadas, todosAmados];
}
