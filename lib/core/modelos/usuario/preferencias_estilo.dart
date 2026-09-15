// preferencias_estilo.dart — Preferencias granulares de estilo visual:
// controla qué componentes usan colores dinámicos (Spotify) y cuáles
// mantienen el diseño fijo (Clásico). Cada flag corresponde a un
// componente visual de la app.

import "package:flutter/foundation.dart";
import 'dart:convert';

/// Preferencias de estilo por componente visual.
class PreferenciasEstilo {
  /// Cards de canción (TarjetaTrack) usan color del cover.
  final bool cardsCancion;

  /// Cards de grilla (álbum/playlist/artista) usan color del cover.
  final bool cardsGrilla;

  /// Fondo principal (home) usa color del cover.
  final bool fondoPrincipal;

  /// Fondo del reproductor usa color del cover.
  final bool fondoReproductor;

  /// Fondos de modals (settings, cola, letras) usan color del cover.
  final bool fondosModals;

  const PreferenciasEstilo({
    this.cardsCancion = false,
    this.cardsGrilla = false,
    this.fondoPrincipal = false,
    this.fondoReproductor = false,
    this.fondosModals = false,
  });

  /// Todos los componentes activados (modo Spotify completo).
  bool get todosActivos =>
      cardsCancion &&
      cardsGrilla &&
      fondoPrincipal &&
      fondoReproductor &&
      fondosModals;

  /// Ningún componente activado (modo Clásico puro).
  bool get ningunoActivo =>
      !cardsCancion &&
      !cardsGrilla &&
      !fondoPrincipal &&
      !fondoReproductor &&
      !fondosModals;

  /// Crea una copia con los campos indicados cambiados.
  PreferenciasEstilo copiarCon({
    bool? cardsCancion,
    bool? cardsGrilla,
    bool? fondoPrincipal,
    bool? fondoReproductor,
    bool? fondosModals,
  }) {
    return PreferenciasEstilo(
      cardsCancion: cardsCancion ?? this.cardsCancion,
      cardsGrilla: cardsGrilla ?? this.cardsGrilla,
      fondoPrincipal: fondoPrincipal ?? this.fondoPrincipal,
      fondoReproductor: fondoReproductor ?? this.fondoReproductor,
      fondosModals: fondosModals ?? this.fondosModals,
    );
  }

  /// Serializa a JSON para persistencia.
  Map<String, dynamic> aJson() => {
        'cardsCancion': cardsCancion,
        'cardsGrilla': cardsGrilla,
        'fondoPrincipal': fondoPrincipal,
        'fondoReproductor': fondoReproductor,
        'fondosModals': fondosModals,
      };

  /// Deserializa desde JSON.
  factory PreferenciasEstilo.desdeJson(Map<String, dynamic> json) {
    return PreferenciasEstilo(
      cardsCancion: json['cardsCancion'] == true,
      cardsGrilla: json['cardsGrilla'] == true,
      fondoPrincipal: json['fondoPrincipal'] == true,
      fondoReproductor: json['fondoReproductor'] == true,
      fondosModals: json['fondosModals'] == true,
    );
  }

  /// Serializa a string JSON para guardado en BD.
  String toJsonString() => jsonEncode(aJson());

  /// Deserializa desde string JSON.
  static PreferenciasEstilo desdeJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return const PreferenciasEstilo();
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) {
        return PreferenciasEstilo.desdeJson(parsed);
      }
    } catch (e) { debugPrint("[App] $e"); }
    return const PreferenciasEstilo();
  }

  /// Estilo "Spotify completo" — todos los flags activados.
  static const spotifyCompleto = PreferenciasEstilo(
    cardsCancion: true,
    cardsGrilla: true,
    fondoPrincipal: true,
    fondoReproductor: true,
    fondosModals: true,
  );

  /// Estilo "Clásico" — todos los flags desactivados.
  static const clasico = PreferenciasEstilo();
}
