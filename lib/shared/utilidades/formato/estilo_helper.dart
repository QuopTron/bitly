// estilo_helper.dart — Helper para leer el estilo visual actual
// desde cualquier widget. Evita importar sl + ValueNotifier en cada archivo.

import 'package:flutter/material.dart';

import '../../../app/inyeccion.dart';
import '../../../core/cache/almacenes/cache_ajustes.dart';
import '../../../core/modelos/usuario/estilo_visual.dart';
import '../../../core/modelos/usuario/preferencias_estilo.dart';

/// Helper para consultar el estilo visual actual.
class EstiloHelper {
  EstiloHelper._();

  /// Estilo visual actual (lee el ValueNotifier global).
  static EstiloVisual actual(BuildContext context) =>
      sl<ValueNotifier<EstiloVisual>>().value;

  /// Retorna `true` si el estilo activo es Spotify.
  static bool esSpotify(BuildContext context) =>
      actual(context) == EstiloVisual.spotify;

  /// Preferencias granulares de estilo por componente.
  static PreferenciasEstilo preferencias(BuildContext context) =>
      sl<ValueNotifier<PreferenciasEstilo>>().value;

  /// Si el componente "cards de canción" usa color dinámico.
  static bool cardsCancion(BuildContext context) =>
      esSpotify(context) && preferencias(context).cardsCancion;

  /// Si el componente "cards de grilla" usa color dinámico.
  static bool cardsGrilla(BuildContext context) =>
      esSpotify(context) && preferencias(context).cardsGrilla;

  /// Si el componente "fondo principal" usa color dinámico.
  static bool fondoPrincipal(BuildContext context) =>
      esSpotify(context) && preferencias(context).fondoPrincipal;

  /// Si el componente "fondo reproductor" usa color dinámico.
  static bool fondoReproductor(BuildContext context) =>
      esSpotify(context) && preferencias(context).fondoReproductor;

  /// Si el componente "fondos de modals" usa color dinámico.
  static bool fondosModals(BuildContext context) =>
      esSpotify(context) && preferencias(context).fondosModals;

  /// Cambia el estilo visual y lo persiste.
  static void cambiar(BuildContext context, EstiloVisual estilo) {
    sl<ValueNotifier<EstiloVisual>>().value = estilo;
    sl<CacheAjustes>().guardarEstiloVisual(estilo.clave);
    // Si se cambia a Spotify, activa todos los componentes.
    // Si se cambia a Clásico, desactiva todos.
    if (estilo == EstiloVisual.spotify) {
      cambiarPreferencias(context, PreferenciasEstilo.spotifyCompleto);
    } else {
      cambiarPreferencias(context, PreferenciasEstilo.clasico);
    }
  }

  /// Cambia las preferencias granulares y las persiste.
  static void cambiarPreferencias(
      BuildContext context, PreferenciasEstilo prefs) {
    sl<ValueNotifier<PreferenciasEstilo>>().value = prefs;
    sl<CacheAjustes>().guardarPreferenciasEstilo(prefs);
  }

  /// Cambia un flag individual de preferencias.
  static void cambiarFlag(
      BuildContext context, String flag, bool valor) {
    final actual = preferencias(context);
    PreferenciasEstilo nuevas;
    switch (flag) {
      case 'cardsCancion':
        nuevas = actual.copiarCon(cardsCancion: valor);
      case 'cardsGrilla':
        nuevas = actual.copiarCon(cardsGrilla: valor);
      case 'fondoPrincipal':
        nuevas = actual.copiarCon(fondoPrincipal: valor);
      case 'fondoReproductor':
        nuevas = actual.copiarCon(fondoReproductor: valor);
      case 'fondosModals':
        nuevas = actual.copiarCon(fondosModals: valor);
      default:
        return;
    }
    cambiarPreferencias(context, nuevas);
  }
}

