// ─────────────────────────────────────────────────────────────
// estado_like.dart — Estado del cubit de likes: huellas de items
// amados, datos de todos los favoritos y flags de carga/error.
// Incluye el helper para limpiar rutas locales de carátula viejas.
// Se conecta con: LikeCubit (estado del cubit).
// Parte del flujo: Mi Espacio → Favoritos y botones de like.
// ─────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

/// Devuelve [path] solo si es una ruta local de carátula usable.
/// Las filas legacy guardaban la URL HTTP del caché de escritorio
/// (http://127.0.0.1:55009/cover/...) que no existe en móvil; esos valores
/// se tratan como "sin carátula local" para que la tarjeta use la de red.
String? limpiarRutaCaratulaLocal(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.contains('127.0.0.1')) return null;
  return path;
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
  final String? error;
  final Set<String> huellasAmadas;
  final Map<String, DatosItemAmado> todosAmados;

  const EstadoLikes({
    this.cargando = false,
    this.error,
    this.huellasAmadas = const {},
    this.todosAmados = const {},
  });

  EstadoLikes copiarCon({
    bool? cargando,
    String? error,
    Set<String>? huellasAmadas,
    Map<String, DatosItemAmado>? todosAmados,
    bool limpiarError = false,
  }) =>
      EstadoLikes(
        cargando: cargando ?? this.cargando,
        error: limpiarError ? null : (error ?? this.error),
        huellasAmadas: huellasAmadas ?? this.huellasAmadas,
        todosAmados: todosAmados ?? this.todosAmados,
      );

  @override
  List<Object?> get props => [cargando, error, huellasAmadas, todosAmados];
}