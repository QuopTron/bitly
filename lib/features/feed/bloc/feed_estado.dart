// ─────────────────────────────────────────────────────────────
// feed_estado.dart — Estado del bloc de feed: secciones del home
// feed (por fuente), ids amados, loading, error, el username del
// saludo y la fuente seleccionada. Las secciones vienen del
// backend Go (getHomeFeed) y se cachean para recuperación offline.
// Se conecta con: modelos (SeccionFeed).
// Parte del flujo: feed de inicio (estado del BlocFeed).
// ─────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

import '../../../core/modelos/seccion_feed.dart';

/// Estado del bloc de feed de inicio.
class EstadoFeed extends Equatable {
  final List<SeccionFeed> secciones;
  final Set<String> idsAmados;
  final bool cargando;
  final String? error;
  final String usuario;
  final String fuenteSeleccionada;

  const EstadoFeed({
    this.secciones = const [],
    this.idsAmados = const {},
    this.cargando = false,
    this.error,
    this.usuario = '',
    this.fuenteSeleccionada = '',
  });

  EstadoFeed copiarCon({
    List<SeccionFeed>? secciones,
    Set<String>? idsAmados,
    bool? cargando,
    String? error,
    String? usuario,
    String? fuenteSeleccionada,
  }) =>
      EstadoFeed(
        secciones: secciones ?? this.secciones,
        idsAmados: idsAmados ?? this.idsAmados,
        cargando: cargando ?? this.cargando,
        error: error,
        usuario: usuario ?? this.usuario,
        fuenteSeleccionada: fuenteSeleccionada ?? this.fuenteSeleccionada,
      );

  @override
  List<Object?> get props => [
        secciones,
        idsAmados,
        cargando,
        error,
        usuario,
        fuenteSeleccionada,
      ];
}